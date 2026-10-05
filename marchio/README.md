# Marchio

Il logo di Lista Spesa Facile: carrello bianco con la spunta arancione su un quadrato verde arrotondato (#2f6b3a).
`logo.svg` è la sorgente (è anche `site/favicon.svg`, il logo in alto sul sito); i PNG, con lo sfondo trasparente,
sono generati da lì.

| File | Uso |
|---|---|
| `logo.svg` | sorgente; sito (favicon e testata) |
| `logo-120.png` | Google Auth Platform → Branding (logo dell'app, 120×120) |
| `logo-150.png` | Login with Amazon → Security Profile (logo nella schermata di consenso) |
| `logo-512.png` | app (`app/assets/logos/lista_spesa_facile.png`), Play Store (icona 512×512) |
| `logo-1024.png` | dove serve più grande |

## Play Store

| File | Uso |
|---|---|
| `grafica-play-1024x500.png` | Scheda dello Store → immagine in primo piano (da `sorgenti/grafica-play.html`) |
| `screenshot-play/` | Screenshot per telefono, 1080×1920 |
| `screenshot-play-tablet-7/`, `screenshot-play-tablet-10/` | Screenshot per tablet 7" e 10", 1440×2560 |

Si rigenerano con `python3 marchio/sorgenti/grafica-play.py` e `python3 marchio/sorgenti/screenshot-play.py`
(Playwright per Python). Le catture dell'emulatore sono in `sorgenti/catture/`, fatte sul backend locale con utenti
e liste di esempio.
