"""Genera gli screenshot del Play Store dalle catture dell'emulatore in catture/ (serve Playwright):
telefono in marchio/screenshot-play/ (1080×1920), tablet 7" e 10" in screenshot-play-tablet-7/ e -10/ (1440×2560).
Le catture dei tablet vengono dal Pixel 8 con `adb shell wm size 1080x1920` (7") o `1440x2560` (10") e `wm density 280`."""
from pathlib import Path
from urllib.parse import urlencode
from playwright.sync_api import sync_playwright

SCHERMATE = [
    ("1-liste.png", "a_liste.png", "Tutte le tue <em>liste</em>", "Organizzate per giorno, con quello che manca"),
    ("2-lista.png", "b_lista.png", "Ordinata per <em>reparto</em>", "Spunta quello che prendi: lo vedono tutti"),
    ("3-chat.png", "c_chat.png", "La <em>chat</em> nella lista", "«Prendo anche il pane?» Senza altre app"),
    ("4-condivisione.png", "e_share.png", "Condivisa in <em>tempo reale</em>", "Invita chi vive con te con la sua email"),
    ("5-info.png", "d_info.png", "Sai cosa <em>compri</em>", "Valori nutrizionali, allergeni e ingredienti"),
    ("6-prezzi.png", "f_prezzi.png", "I tuoi <em>prezzi</em>", "Annota quanto paghi, li vedi solo tu"),
]

qui = Path(__file__).resolve().parent
DISPOSITIVI = [("screenshot-play", "", 1), ("screenshot-play-tablet-7", "tablet-7/", 4 / 3),
               ("screenshot-play-tablet-10", "tablet-10/", 4 / 3)]
with sync_playwright() as p:
    browser = p.chromium.launch()
    for cartella, catture, scala in DISPOSITIVI:
        uscita = qui.parent / cartella
        uscita.mkdir(exist_ok=True)
        pagina = browser.new_page(viewport={"width": 1080, "height": 1920}, device_scale_factor=scala)
        for nome, img, titolo, sotto in SCHERMATE:
            query = {"img": catture + img, "t": titolo, "s": sotto, **({"tablet": 1} if catture else {})}
            pagina.goto((qui / "screenshot-play.html").as_uri() + "?" + urlencode(query))
            pagina.wait_for_load_state("networkidle")
            pagina.wait_for_timeout(200)
            pagina.screenshot(path=str(uscita / nome))
        pagina.close()
    browser.close()
