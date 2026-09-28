<?php

namespace App\Notifications;

use Illuminate\Support\Str;

/**
 * Nuovo messaggio nella chat di una lista: solo push (la chat ha già il suo storico).
 */
class ChatMessageReceived extends AppNotification
{
    public function __construct(
        public string $senderName,
        public int $chatListId,
        public string $listName,
        public ?string $message,
        public ?int $messageId = null,
        public bool $hasImage = false,
    ) {}

    public function kind(): string
    {
        return 'chat_message';
    }

    public function title(): string
    {
        return __('app.notifications.chat_title', ['sender' => $this->senderName, 'list' => $this->listName]);
    }

    public function body(): string
    {
        // Foto: "📷 Foto" o "📷 didascalia", nella lingua di chi riceve.
        $text = Str::limit((string) $this->message, 180);

        return match (true) {
            ! $this->hasImage => $text,
            $text !== '' => '📷 '.$text,
            default => '📷 '.__('app.notifications.photo'),
        };
    }

    public function listId(): ?int
    {
        return $this->chatListId;
    }

    /**
     * @return array<string, int|string|null>
     */
    public function extra(): array
    {
        return ['message_id' => $this->messageId];
    }

    public function sender(): ?string
    {
        return $this->senderName;
    }

    public function listName(): ?string
    {
        return $this->listName;
    }

    protected function stored(): bool
    {
        return false;
    }

    public function pushTag(): ?string
    {
        // Stesso tag delle modifiche alla lista: una sola conversazione per lista, come in WhatsApp.
        return 'list-'.$this->chatListId;
    }
}
