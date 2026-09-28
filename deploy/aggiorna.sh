#!/usr/bin/env bash
#
# Porta Lista Spesa Facile sulla VPS all'ultimo main di GitHub. Stesso schema di magopdf-aggiorna.
#
# COME DECIDE. Ogni 5 minuti (timer systemd) confronta il commit locale con origin/main. Uguali: esce in
# silenzio, senza scrivere nel registro.
#
# COSA FA. Marca l'immagine in uso come "precedente", avanza a main (solo --ff-only), ricostruisce e riavvia.
# Le migrazioni partono da sole all'avvio del container app. Se e' cambiato il Caddyfile ricrea anche Caddy:
# e' montato come file singolo, e git lo sostituisce con un file nuovo che il container non vedrebbe.
#
# LA RETE DI SICUREZZA. Dopo l'avvio interroga lo stack dal suo Caddy, senza passare dall'edge (cosi' un
# problema dell'edge non fa tornare indietro LSF): sito 200, /up e /api/config 200 con la chiave dell'app.
# Se non rispondono entro due minuti si torna all'immagine e al commit di prima.
# Una migrazione gia' eseguita pero' non si annulla: quelle che rinominano o cancellano colonne vanno
# pubblicate con attenzione, non affidate al ritorno automatico.
#
# COSA NON FA. Salta se ci sono modifiche locali non committate, e si ferma se i rami sono divergenti.
#
# Uso:
#   lsf-aggiorna                 una passata sola, adesso
#   lsf-aggiorna --forza         ricostruisce e controlla anche se non e' cambiato niente
#   lsf-aggiorna --stato         cosa c'e' e cosa ci sarebbe, senza toccare
#   ./aggiorna.sh --installa     si copia in /usr/local/sbin e accende il timer
#   ./aggiorna.sh --disinstalla  spegne il timer
#
set -euo pipefail

BASE=${LSF_BASE:-/opt/listaspesafacile}
LOG=/var/log/lsf-aggiorna.log
LOCK=/var/lock/lsf-aggiorna.lock
OGNI=${LSF_OGNI:-5min}
INSTALLATO=/usr/local/sbin/lsf-aggiorna
NOME=lsf-aggiorna
IMMAGINE=listaspesafacile-be

dire() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }

installa() {
  [ "$(id -u)" = 0 ] || { echo "serve root: sudo $0 --installa"; exit 1; }
  install -m 755 "$(readlink -f "$0")" "$INSTALLATO"
  cat > /etc/systemd/system/$NOME.service <<CONF
[Unit]
Description=Aggiorna Lista Spesa Facile dall'ultimo main di GitHub
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
Environment=LSF_BASE=${BASE}
ExecStart=${INSTALLATO}
# Una build puo' durare parecchio: meglio nessun limite che un'immagine a meta'.
TimeoutStartSec=0
CONF
  cat > /etc/systemd/system/$NOME.timer <<CONF
[Unit]
Description=Controlla ogni ${OGNI} se c'e' un main nuovo per Lista Spesa Facile

[Timer]
OnBootSec=5min
OnUnitActiveSec=${OGNI}
Persistent=true
RandomizedDelaySec=45

[Install]
WantedBy=timers.target
CONF
  systemctl daemon-reload
  systemctl enable --now $NOME.timer
  touch "$LOG"; chmod 640 "$LOG"
  echo "  installato: controlla ogni ${OGNI}"
  echo "  stato:    systemctl list-timers $NOME.timer"
  echo "  registro: tail -f ${LOG}"
  exit 0
}

disinstalla() {
  [ "$(id -u)" = 0 ] || { echo "serve root"; exit 1; }
  systemctl disable --now $NOME.timer 2>/dev/null || true
  rm -f /etc/systemd/system/$NOME.{service,timer}
  systemctl daemon-reload
  echo "  timer spento. Lo script resta in ${INSTALLATO}."
  exit 0
}

stato() {
  cd "$BASE"
  git fetch -q origin main 2>/dev/null || { echo "  GitHub non raggiungibile"; exit 0; }
  if [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]; then
    echo "  listaspesafacile: aggiornato ($(git rev-parse --short HEAD))"
  else
    echo "  listaspesafacile: $(git rev-list --count HEAD..origin/main) commit da prendere"
    git log --oneline HEAD..origin/main | sed 's/^/      /'
  fi
  [ -n "$(git status --porcelain)" ] && echo "      ATTENZIONE: modifiche locali, verrebbe saltato"
  exit 0
}

case "${1:-}" in
  --installa)    installa ;;
  --disinstalla) disinstalla ;;
  --stato)       stato ;;
  --forza)       FORZA=1 ;;
  "")            FORZA=0 ;;
  *) echo "opzione sconosciuta: $1"; exit 2 ;;
esac

exec 9>"$LOCK"
flock -n 9 || { echo "un aggiornamento e' gia' in corso"; exit 0; }

cd "$BASE"
if [ -n "$(git status --porcelain)" ]; then
  dire "modifiche locali non committate in $BASE: non aggiorno"
  exit 0
fi
git fetch -q origin main || { dire "non riesco a raggiungere GitHub"; exit 1; }
PRIMA=$(git rev-parse HEAD)
if [ "$PRIMA" = "$(git rev-parse origin/main)" ] && [ "$FORZA" = 0 ]; then
  exit 0
fi

# ------------------------------------------------------------- le sonde
# Dal Caddy dello stack, con il suo wget: niente edge in mezzo, niente immagini in piu'.
env_val() { grep -E "^$1=" .env | tail -1 | cut -d= -f2-; }
SITO=$(env_val SITE_HOST)
CHIAVE=$(env_val CLIENT_KEY)
sonda() {                          # $1 = host, $2 = percorso — riuscita se risponde 2xx
  docker compose exec -T caddy wget -q -O /dev/null -T 10 \
    --header "Host: $1" --header "X-App-Key: $CHIAVE" "http://127.0.0.1$2" 2>/dev/null
}
sano() { sonda "$SITO" / && sonda "api.$SITO" /up && sonda "api.$SITO" /api/config; }
attende() {                        # fino a due minuti
  local _
  for _ in $(seq 1 40); do sano && return 0; sleep 3; done
  return 1
}

docker image inspect "$IMMAGINE:latest" >/dev/null 2>&1 && docker tag "$IMMAGINE:latest" "$IMMAGINE:precedente"

torna_indietro() {
  dire "$1: torno all'immagine e al commit di prima"
  docker image inspect "$IMMAGINE:precedente" >/dev/null 2>&1 && docker tag "$IMMAGINE:precedente" "$IMMAGINE:latest"
  git reset -q --hard "$PRIMA"
  docker compose up -d --force-recreate >>"$LOG" 2>&1 || true
  if attende; then dire "rientro riuscito: lo stack e' tornato come prima"; else dire "RIENTRO FALLITO: serve un intervento a mano"; fi
  exit 1
}

git merge -q --ff-only origin/main || { dire "avanzamento lineare impossibile (rami divergenti), mi fermo"; exit 1; }
DOPO=$(git rev-parse HEAD)
dire "ora a $(git rev-parse --short HEAD) — $(git log -1 --format=%s | cut -c1-60)"

docker compose build >>"$LOG" 2>&1 || torna_indietro "build fallita"
docker compose up -d >>"$LOG" 2>&1 || torna_indietro "avvio fallito"
if ! git diff --quiet "$PRIMA" "$DOPO" -- backend/docker/Caddyfile; then
  docker compose up -d --force-recreate caddy >>"$LOG" 2>&1 || torna_indietro "Caddy non riparte"
  dire "Caddyfile cambiato: Caddy ricreato"
fi

attende || torna_indietro "lo stack non risponde dopo l'aggiornamento"

NUOVO="$BASE/deploy/aggiorna.sh"
if [ -f "$NUOVO" ] && [ -f "$INSTALLATO" ] && ! cmp -s "$NUOVO" "$INSTALLATO"; then
  install -m 755 "$NUOVO" "$INSTALLATO"
  dire "aggiornato anche lo script di aggiornamento"
fi

dire "fatto: sito, /up e /api/config rispondono"
