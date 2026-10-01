// Eliminazione dell'account in due passi: email → codice ricevuto per email → account eliminato.
// Le chiamate vanno allo stesso dominio del sito (/api/account-deletion/*), che Caddy passa a Laravel.
// I messaggi sono nella lingua della pagina (<html lang="…">).
(() => {
  const testi = {
    it: {
      troppi: 'Troppi tentativi. Aspetta un minuto e riprova.',
      email503: "In questo momento non riusciamo a mandare l'email. Riprova più tardi o scrivi a support@listaspesafacile.com.",
      generico: 'Qualcosa non ha funzionato. Riprova tra poco.',
      rete: 'Connessione non riuscita. Controlla la rete e riprova.',
      email: 'Scrivi un indirizzo email valido.',
      cifre: 'Il codice è di 6 cifre.',
      spunta: "Spunta la casella per confermare che l'eliminazione è definitiva.",
      codice: 'Codice non valido o scaduto. Controlla o richiedine uno nuovo.',
    },
    en: {
      troppi: 'Too many attempts. Wait a minute and try again.',
      email503: "We can't send the email right now. Try again later or write to support@listaspesafacile.com.",
      generico: 'Something went wrong. Try again shortly.',
      rete: 'Connection failed. Check your network and try again.',
      email: 'Enter a valid email address.',
      cifre: 'The code has 6 digits.',
      spunta: 'Tick the box to confirm that the deletion is permanent.',
      codice: 'Invalid or expired code. Check it or ask for a new one.',
    },
    fr: {
      troppi: 'Trop de tentatives. Attendez une minute et réessayez.',
      email503: "Nous ne pouvons pas envoyer l'e-mail pour le moment. Réessayez plus tard ou écrivez à support@listaspesafacile.com.",
      generico: "Quelque chose n'a pas fonctionné. Réessayez dans un instant.",
      rete: 'Connexion impossible. Vérifiez le réseau et réessayez.',
      email: 'Saisissez une adresse e-mail valide.',
      cifre: 'Le code comporte 6 chiffres.',
      spunta: 'Cochez la case pour confirmer que la suppression est définitive.',
      codice: 'Code non valide ou expiré. Vérifiez-le ou demandez-en un nouveau.',
    },
    de: {
      troppi: 'Zu viele Versuche. Warte eine Minute und versuche es erneut.',
      email503: 'Wir können die E-Mail gerade nicht senden. Versuche es später erneut oder schreib an support@listaspesafacile.com.',
      generico: 'Etwas hat nicht funktioniert. Versuche es gleich noch einmal.',
      rete: 'Verbindung fehlgeschlagen. Prüfe das Netz und versuche es erneut.',
      email: 'Gib eine gültige E-Mail-Adresse ein.',
      cifre: 'Der Code hat 6 Ziffern.',
      spunta: 'Hake das Kästchen an, um zu bestätigen, dass die Löschung endgültig ist.',
      codice: 'Ungültiger oder abgelaufener Code. Prüfe ihn oder fordere einen neuen an.',
    },
    es: {
      troppi: 'Demasiados intentos. Espera un minuto y vuelve a intentarlo.',
      email503: 'Ahora mismo no podemos enviar el correo. Inténtalo más tarde o escribe a support@listaspesafacile.com.',
      generico: 'Algo no ha funcionado. Inténtalo de nuevo en un momento.',
      rete: 'No se ha podido conectar. Comprueba la red y vuelve a intentarlo.',
      email: 'Escribe una dirección de correo válida.',
      cifre: 'El código tiene 6 cifras.',
      spunta: 'Marca la casilla para confirmar que la eliminación es definitiva.',
      codice: 'Código no válido o caducado. Compruébalo o pide uno nuevo.',
    },
  };
  const t = testi[document.documentElement.lang] || testi.it;

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
    if (stato === 429) return t.troppi;
    if (stato === 503) return t.email503;
    return t.generico;
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
      avvisa(t.rete);
      return null;
    } finally {
      pulsante.disabled = false;
    }
  };

  passoEmail.addEventListener('submit', async (evento) => {
    evento.preventDefault();
    const campo = passoEmail.elements.email;
    if (!campo.checkValidity()) {
      avvisa(t.email);
      campo.focus();
      return;
    }
    email = campo.value.trim();
    const risposta = await invia('code', { email }, passoEmail.querySelector('button'));
    if (!risposta) return;
    if (!risposta.ok) {
      avvisa(risposta.status === 422 ? t.email : errore(risposta.status));
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
      avvisa(t.cifre);
      return;
    }
    if (!document.getElementById('capito').checked) {
      avvisa(t.spunta);
      return;
    }
    const risposta = await invia('confirm', { email, code }, passoCodice.querySelector('button[type=submit]'));
    if (!risposta) return;
    if (!risposta.ok) {
      avvisa(risposta.status === 422 ? t.codice : errore(risposta.status));
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
