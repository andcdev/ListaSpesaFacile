<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ListMessage;
use App\Models\Report;
use App\Models\ShoppingList;
use App\Notifications\ReportReceived;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Notification;
use Illuminate\Validation\Rule;
use Throwable;

/**
 * Segnalazioni dall'app: un problema, una persona o un messaggio della chat. Arrivano per email all'assistenza
 * (config mail.support) e restano nella tabella reports.
 */
class ReportController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', Rule::in(Report::TYPES)],
            // Per un problema il testo serve; per una persona o un messaggio è facoltativo.
            'body' => [Rule::requiredIf($request->input('type') === 'problem'), 'nullable', 'string', 'max:5000'],
            'user_id' => ['required_if:type,user', 'nullable', 'integer', 'exists:users,id'],
            'list_id' => ['required_if:type,message', 'nullable', 'integer'],
            'message_id' => ['required_if:type,message', 'nullable', 'integer'],
            'app_version' => ['sometimes', 'nullable', 'string', 'max:30'],
        ]);

        $user = $request->user();
        $report = new Report([
            'type' => $data['type'],
            'body' => trim($data['body'] ?? '') ?: null,
            'app_version' => $data['app_version'] ?? null,
        ]);
        $report->user()->associate($user);

        // La lista (e il messaggio) si possono segnalare solo se li si vede.
        if (! empty($data['list_id'])) {
            $list = ShoppingList::findOrFail($data['list_id']);
            $this->authorize('view', $list);
            $report->shopping_list_id = $list->id;

            if (! empty($data['message_id'])) {
                $message = ListMessage::whereBelongsTo($list)->findOrFail($data['message_id']);
                $report->list_message_id = $message->id;
                $report->message_body = $message->body;
                $report->reported_user_id = $message->user_id;
            }
        }
        if (! empty($data['user_id'])) {
            abort_if((int) $data['user_id'] === $user->id, 422);
            $report->reported_user_id = (int) $data['user_id'];
        }
        $report->save();

        try {
            Notification::route('mail', config('mail.support.address'))
                ->notify((new ReportReceived($report->load(['user', 'reportedUser', 'shoppingList.owner', 'listMessage'])))->locale('it'));
        } catch (Throwable $e) {
            report($e);
            abort(503, __('app.errors.mail_unavailable'));
        }

        return response()->json(['message' => __('app.report_sent')], 201);
    }
}
