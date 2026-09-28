// Eliminazione dell'account in due passi: email → codice ricevuto per email → account eliminato.
// Le chiamate vanno allo stesso dominio del sito (/api/account-deletion/*), che Caddy passa a Laravel.
(() => {
  const passoEmail = document.getElementById('passo-email');
  const passoCodice = document.getElementById('passo-codice');
  const fatto = document.getElementById('fatto');
  const messaggio = document.getElementById('messaggio');
  let email = '';

  const avvisa = (testo) => {
    messaggio.textContent = testo;
    messaggio.hidden = !testo;
  };

  const errore = (stato) => {
    if (stato === 429) return 'Troppi tentativi. Aspetta un minuto e riprova.';
    if (stato === 503) return "In questo momento non riusciamo a mandare l'email. Riprova più tardi o scrivi a supporto@listaspesafacile.com.";
    return 'Qualcosa non ha funzionato. Riprova tra poco.';
  };

  const invia = async (percorso, dati, pulsante) => {
    pulsante.disabled = true;
    avvisa('');
    try {
      return await fetch(`/api/account-deletion/${percorso}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify(dati),
      });
    } catch {
      avvisa('Connessione non riuscita. Controlla la rete e riprova.');
      return null;
    } finally {
      pulsante.disabled = false;
    }
  };

  passoEmail.addEventListener('submit', async (evento) => {
    evento.preventDefault();
    const campo = passoEmail.elements.email;
    if (!campo.checkValidity()) {
      avvisa("Scrivi un indirizzo email valido.");
      campo.focus();
      return;
    }
    email = campo.value.trim();
    const risposta = await invia('code', { email }, passoEmail.querySelector('button'));
    if (!risposta) return;
    if (!risposta.ok) {
      avvisa(risposta.status === 422 ? 'Scrivi un indirizzo email valido.' : errore(risposta.status));
      return;
    }
    document.getElementById('email-scelta').textContent = email;
    passoEmail.hidden = true;
    passoCodice.hidden = false;
    passoCodice.elements.codice.focus();
  });

  passoCodice.addEventListener('submit', async (evento) => {
    evento.preventDefault();
    const code = passoCodice.elements.codice.value.trim();
    if (!/^\d{6}$/.test(code)) {
      avvisa('Il codice è di 6 cifre.');
      return;
    }
    if (!document.getElementById('capito').checked) {
      avvisa("Spunta la casella per confermare che l'eliminazione è definitiva.");
      return;
    }
    const risposta = await invia('confirm', { email, code }, passoCodice.querySelector('button[type=submit]'));
    if (!risposta) return;
    if (!risposta.ok) {
      avvisa(risposta.status === 422 ? 'Codice non valido o scaduto. Controlla o richiedine uno nuovo.' : errore(risposta.status));
      return;
    }
    passoCodice.hidden = true;
    fatto.hidden = false;
  });

  document.getElementById('rimanda').addEventListener('click', () => {
    passoCodice.hidden = true;
    passoCodice.reset();
    passoEmail.hidden = false;
    avvisa('');
    passoEmail.elements.email.focus();
  });
})();
