{{-- Email all'assistenza: segnalazione dall'app o foto rifiutata dal controllo automatico. --}}
<x-mail::message>
# {{ $title }}

@foreach ($lines as $line)
{{ $line }}

@endforeach
@if ($quote !== null)
<x-mail::panel>
{{ $quote }}
</x-mail::panel>
@endif
@if ($imageUrl)
<x-mail::button :url="$imageUrl" color="primary">
Guarda la foto
</x-mail::button>

@endif
@if ($person)

**Account di {{ $person->name }}:** {{ $person->isSuspended() ? 'già sospeso' : 'attivo' }}.

<x-mail::button :url="$suspendUrl" color="error">
Sospendi account
</x-mail::button>

<x-mail::button :url="$warningMailto" color="success">
Scrivi un avviso all'utente
</x-mail::button>

@endif
<small>I pulsanti valgono {{ $validDays }} giorni. «Sospendi account» chiede conferma prima di sospendere; «Scrivi un avviso» apre un'email già scritta nella lingua dell'utente, da rileggere prima di inviarla.@if ($imageUrl) Le foto rifiutate restano disponibili per {{ $quarantineDays }} giorni.@endif</small>

Lista Spesa Facile
</x-mail::message>
