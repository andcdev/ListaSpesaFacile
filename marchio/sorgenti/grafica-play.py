"""Genera marchio/grafica-play-1024x500.png da grafica-play.html (serve Playwright per Python)."""
from pathlib import Path
from playwright.sync_api import sync_playwright

qui = Path(__file__).resolve().parent
with sync_playwright() as p:
    browser = p.chromium.launch()
    pagina = browser.new_page(viewport={"width": 1024, "height": 500})
    pagina.goto((qui / "grafica-play.html").as_uri())
    pagina.wait_for_timeout(300)
    pagina.screenshot(path=str(qui.parent / "grafica-play-1024x500.png"))
    browser.close()
