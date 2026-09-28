<?php

namespace Tests\Feature;

use App\Models\DeviceToken;
use App\Models\ShoppingList;
use App\Models\User;
use App\Support\Fcm;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PushTest extends TestCase
{
    use RefreshDatabase;

    private const FCM_URL = 'https://fcm.googleapis.com/v1/projects/lista-test/messages:send';

    private string $credentials;

    protected function setUp(): void
    {
        parent::setUp();

        // Service account fittizio con una vera chiave RSA, per firmare il JWT.
        $key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
        openssl_pkey_export($key, $pem);
        $this->credentials = tempnam(sys_get_temp_dir(), 'fcm');
        file_put_contents($this->credentials, json_encode([
            'project_id' => 'lista-test',
            'client_email' => 'push@lista-test.iam.gserviceaccount.com',
            'private_key' => $pem,
            'token_uri' => 'https://oauth2.googleapis.com/token',
        ]));
        config(['services.fcm.credentials' => $this->credentials]);
    }

    protected function tearDown(): void
    {
        @unlink($this->credentials);
        parent::tearDown();
    }

    public function test_config_tells_the_app_whether_push_is_active(): void
    {
        $this->getJson('/api/config')->assertJsonPath('push', true);

        config(['services.fcm.credentials' => '/non/esiste.json']);
        $this->app->forgetInstance(Fcm::class);
        $this->getJson('/api/config')->assertJsonPath('push', false);
    }

    public function test_device_token_belongs_to_the_last_user(): void
    {
        $anna = User::factory()->create();
        $bruno = User::factory()->create();

        Sanctum::actingAs($anna);
        $this->postJson('/api/devices', ['token' => 'tok-1'])->assertNoContent();
        Sanctum::actingAs($bruno);
        $this->postJson('/api/devices', ['token' => 'tok-1'])->assertNoContent();

        $this->assertSame($bruno->id, DeviceToken::firstWhere('token', 'tok-1')->user_id);

        $this->deleteJson('/api/devices', ['token' => 'tok-1'])->assertNoContent();
        $this->assertDatabaseCount('device_tokens', 0);
    }

    public function test_share_sends_push_and_drops_unregistered_tokens(): void
    {
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'ya29.test', 'expires_in' => 3600]),
            self::FCM_URL => Http::sequence()
                ->push(['name' => 'projects/lista-test/messages/1'])
                ->push(['error' => ['code' => 404, 'status' => 'NOT_FOUND', 'details' => [['errorCode' => 'UNREGISTERED']]]], 404),
        ]);
        $list = ShoppingList::factory()->create(['name' => 'Spesa']);
        $list->owner->update(['name' => 'Mario']);
        $anna = User::factory()->create(['email' => 'anna@example.com']);
        $anna->deviceTokens()->createMany([['token' => 'telefono'], ['token' => 'vecchio']]);

        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/shares", ['email' => 'anna@example.com'])->assertOk();

        Http::assertSent(function (Request $request) {
            if ($request->url() !== 'https://oauth2.googleapis.com/token') {
                return false;
            }
            [, $claims] = explode('.', $request['assertion']);
            $claims = json_decode(base64_decode(strtr($claims, '-_', '+/')), true);

            return $claims['iss'] === 'push@lista-test.iam.gserviceaccount.com'
                && $claims['scope'] === 'https://www.googleapis.com/auth/firebase.messaging';
        });
        Http::assertSent(fn (Request $request) => $request->url() === self::FCM_URL
            && $request->hasHeader('Authorization', 'Bearer ya29.test')
            && $request['message']['token'] === 'telefono'
            && $request['message']['data']['title'] === 'Mario ha condiviso con te «Spesa»'
            && ! isset($request['message']['notification']) // Android: solo dati, la notifica la disegna l'app
            && $request['message']['android']['priority'] === 'high'
            && $request['message']['apns']['payload']['aps']['alert']['title'] === 'Mario ha condiviso con te «Spesa»'
            && $request['message']['data']['kind'] === 'list_shared'
            && $request['message']['data']['list_id'] === (string) $list->id
            && $request['message']['data']['channel_id'] === 'lista_spesa');

        $this->assertSame(['telefono'], $anna->deviceTokens()->pluck('token')->all());
    }

    public function test_chat_message_is_pushed_to_the_others_only(): void
    {
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'ya29.test']),
            self::FCM_URL => Http::response(['name' => 'ok']),
        ]);
        $list = ShoppingList::factory()->create(['name' => 'Spesa']);
        $anna = User::factory()->create(['name' => 'Anna']);
        $list->sharedWith()->attach($anna->id);
        $list->owner->deviceTokens()->create(['token' => 'proprietario']);
        $anna->deviceTokens()->create(['token' => 'anna']);

        Sanctum::actingAs($anna);
        $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'Sono al banco frigo'])->assertCreated();

        $pushes = Http::recorded(fn (Request $request) => $request->url() === self::FCM_URL)->values();
        $this->assertCount(1, $pushes);
        [$request] = $pushes[0];
        $this->assertSame('proprietario', $request['message']['token']);
        $this->assertSame('Anna · Spesa', $request['message']['data']['title']);
        $this->assertSame('Sono al banco frigo', $request['message']['data']['body']);
        // Chat e modifiche della stessa lista finiscono nella stessa conversazione sul telefono.
        $this->assertSame('list-'.$list->id, $request['message']['data']['tag']);
        $this->assertSame('list-'.$list->id, $request['message']['apns']['payload']['aps']['thread-id']);
        $this->assertSame('Anna', $request['message']['data']['sender']);
        $this->assertSame('Spesa', $request['message']['data']['list_name']);
    }

    public function test_push_failure_does_not_break_the_request(): void
    {
        Http::fake(['*' => Http::response('errore', 500)]);
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create(['email' => 'anna@example.com']);
        $anna->deviceTokens()->create(['token' => 'anna']);

        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/shares", ['email' => 'anna@example.com'])->assertOk();

        $this->assertDatabaseCount('notifications', 1);
        $this->assertDatabaseCount('device_tokens', 1);
    }
}
