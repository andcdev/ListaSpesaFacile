<?php

namespace App\Notifications;

use App\Notifications\Channels\FcmChannel;
use App\Notifications\Channels\RealtimeChannel;
use App\Support\Fcm;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

/**
 * Base delle notifiche dell'app: salvate nel database (elenco "Notifiche"), inviate in tempo reale
 * all'app aperta e, se Firebase è configurato, come notifica push. Quelle non salvate (chat e modifiche
 * alla lista) arrivano comunque in tempo reale e come push, raggruppate per lista come in WhatsApp.
 *
 * Contengono solo valori semplici (niente modelli), così restano valide in coda anche se la lista
 * nel frattempo viene eliminata.
 */
abstract class AppNotification extends Notification implements ShouldQueue
{
    use Queueable;

    /** Tipo di notifica, usato dall'app per l'icona e per cosa aprire al tocco. */
    abstract public function kind(): string;

    abstract public function title(): string;

    abstract public function body(): string;

    public function listId(): ?int
    {
        return null;
    }

    /** Chi ha scritto o fatto la modifica: l'app lo mostra come mittente nella conversazione della lista. */
    public function sender(): ?string
    {
        return null;
    }

    /**
     * Dati aggiuntivi per l'app (es. id del messaggio, per la conferma di ricezione).
     *
     * @return array<string, int|string|null>
     */
    public function extra(): array
    {
        return [];
    }

    /** Nome della lista, titolo della conversazione sul telefono. */
    public function listName(): ?string
    {
        return null;
    }

    /** false per le notifiche di chat e modifiche: non finiscono nell'elenco dell'app. */
    protected function stored(): bool
    {
        return true;
    }

    /** Notifiche push con lo stesso tag si sostituiscono sul telefono invece di accumularsi. */
    public function pushTag(): ?string
    {
        return null;
    }

    /**
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        return array_values(array_filter([
            $this->stored() ? 'database' : null,
            RealtimeChannel::class,
            app(Fcm::class)->enabled() ? FcmChannel::class : null,
        ]));
    }

    /**
     * Database e tempo reale subito, durante la richiesta; il push (chiamata HTTP a Google)
     * passa dalla coda predefinita, così non rallenta la risposta.
     *
     * @return array<string, string>
     */
    public function viaConnections(): array
    {
        return ['database' => 'sync', RealtimeChannel::class => 'sync'];
    }

    /**
     * Dati salvati nel database.
     *
     * @return array<string, mixed>
     */
    public function toArray(object $notifiable): array
    {
        return [
            'kind' => $this->kind(),
            'title' => $this->title(),
            'body' => $this->body(),
            'list_id' => $this->listId(),
        ];
    }

    /**
     * Stessa forma di NotificationResource, per l'evento in tempo reale e il push.
     *
     * @return array<string, mixed>
     */
    public function payload(object $notifiable): array
    {
        return [
            'id' => $this->id,
            ...$this->toArray($notifiable),
            'sender' => $this->sender(),
            'list_name' => $this->listName(),
            ...$this->extra(),
            // false: da mostrare sul telefono ma non nell'elenco delle notifiche (né nel contatore).
            'stored' => $this->stored(),
            'read' => false,
            'created_at' => now()->toIso8601String(),
        ];
    }
}
