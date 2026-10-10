{{-- Pagina aperta dai pulsanti nelle email all'assistenza: sospensione e riattivazione di un account. --}}
<!doctype html>
<html lang="it">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>Moderazione · Lista Spesa Facile</title>
    <style>
        :root { color-scheme: light dark; --verde: #2f6b3a; --rosso: #b3261e; }
        body { font-family: system-ui, sans-serif; max-width: 34rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }
        .scheda { border: 1px solid #8884; border-radius: 12px; padding: 1rem 1.25rem; margin: 1rem 0; }
        .stato { font-weight: 600; }
        button, .pulsante { display: inline-block; border: 0; border-radius: 8px; padding: .7rem 1.1rem; font-size: 1rem;
            color: #fff; background: var(--verde); text-decoration: none; cursor: pointer; margin: .25rem 0; }
        .pericolo { background: var(--rosso); }
        .secondario { background: #666; }
    </style>
</head>
<body>
    <h1>Moderazione</h1>
    <div class="scheda">
        <div><strong>{{ $user->name }}</strong> &lt;{{ $user->email }}&gt; · utente {{ $user->id }}</div>
        <div>Registrato il {{ $user->created_at?->timezone('Europe/Rome')->format('d/m/Y') }} · segnalazioni e foto rifiutate: {{ $reports }}</div>
        <div class="stato">
            @if ($user->isSuspended())
                Sospeso dal {{ $user->suspended_at->timezone('Europe/Rome')->format('d/m/Y H:i') }}
            @else
                Attivo
            @endif
        </div>
    </div>

    @switch($state)
        @case('confirm-suspend')
            <p>Sospendere l'account? Tutte le sue sessioni vengono chiuse e non potrà più accedere, con nessun metodo.
                Liste e contenuti restano dove sono. Si può riattivare in ogni momento.</p>
            <form method="post" action="{{ request()->fullUrl() }}">
                @csrf
                <button class="pericolo" type="submit">Sospendi account</button>
            </form>
            <p><a class="pulsante secondario" href="{{ $warningMailto }}">Scrivi un avviso all'utente</a></p>
            @break
        @case('suspended')
            <p>Account sospeso. Puoi comunicarlo all'utente con l'email già scritta nella sua lingua.</p>
            <p><a class="pulsante" href="{{ $suspendedMailto }}">Scrivi all'utente che è sospeso</a></p>
            <p><a class="pulsante secondario" href="{{ $reactivateUrl }}">Riattiva account</a></p>
            @break
        @case('confirm-reactivate')
            <p>Riattivare l'account? Potrà di nuovo accedere.</p>
            <form method="post" action="{{ request()->fullUrl() }}">
                @csrf
                <button type="submit">Riattiva account</button>
            </form>
            @break
        @case('active')
            <p>L'account è attivo.</p>
            <p><a class="pulsante pericolo" href="{{ $suspendUrl }}">Sospendi account</a></p>
            @break
    @endswitch
</body>
</html>
