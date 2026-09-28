# secrets

File riservati montati nei container `app`, `worker` e `scheduler` (in sola lettura). Non vanno nel repository.

- `firebase-service-account.json`: chiave del service account Firebase per le notifiche push.
  Console Firebase → Impostazioni progetto → Account di servizio → **Genera nuova chiave privata**.
  Se il file manca, le notifiche push sono disattivate e l'app programma i promemoria sul telefono.
