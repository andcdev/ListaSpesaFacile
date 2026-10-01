"""Icone Android e schermata di avvio dal logo dell'app (../marchio/logo.svg, lo stesso in alto sul sito).

Uso: python3 tool/genera_icone.py   (serve Playwright con Chromium: disegna l'SVG e salva i PNG)

- mipmap-*/ic_launcher.png            icona classica: il logo intero (quadrato verde arrotondato)
- mipmap-*/ic_launcher_foreground.png icona adattiva: solo carrello e spunta, nella zona sicura; lo sfondo è il
                                      verde di values/ic_launcher_background.xml
- mipmap-*/ic_launcher_monochrome.png icone a tema di Android 13+: carrello e spunta tutti bianchi
- drawable-*/splash_logo.png          schermata di avvio: carrello e spunta grandi sul verde
"""

import os
import re

from playwright.sync_api import sync_playwright

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(APP, 'android', 'app', 'src', 'main', 'res')
LOGO = os.path.join(APP, '..', 'marchio', 'logo.svg')
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}

svg = open(LOGO, encoding='utf-8').read()
inner = re.search(r'<svg[^>]*>(.*)</svg>', svg, re.S).group(1)
shapes = re.sub(r'<rect[^>]*/>', '', inner)  # senza il quadrato verde
white = shapes.replace('#e4572e', '#fff')

# Il logo è 64 unità. Icona adattiva: 108 dp, il logo intero ne occupa 72 (il carrello sta nei 66 dp sicuri).
# Avvio di Android 12+: 288 dp, cerchio visibile di 192 dp in cui sta il logo intero. Stessa proporzione 2/3.
FRAMED = '-16 -16 96 96'


def page(view_box: str, body: str) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view_box}">{body}</svg>'


IMAGES = [  # (cartella, file, lato in dp, svg)
    ('mipmap', 'ic_launcher.png', 48, page('0 0 64 64', inner)),
    ('mipmap', 'ic_launcher_foreground.png', 108, page(FRAMED, shapes)),
    ('mipmap', 'ic_launcher_monochrome.png', 108, page(FRAMED, white)),
    ('drawable', 'splash_logo.png', 288, page(FRAMED, shapes)),
]

with sync_playwright() as p:
    browser = p.chromium.launch()
    for folder, name, dp, image in IMAGES:
        for density, factor in DENSITIES.items():
            px = round(dp * factor)
            tab = browser.new_page(viewport={'width': px, 'height': px})
            sized = image.replace('<svg ', f'<svg width="{px}" height="{px}" ', 1)
            tab.set_content(f'<html><body style="margin:0;background:transparent">{sized}</body></html>')
            out = os.path.join(RES, f'{folder}-{density}', name)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            tab.screenshot(path=out, omit_background=True, clip={'x': 0, 'y': 0, 'width': px, 'height': px})
            tab.close()
        print(f'{folder}/{name}: {dp} dp')
    browser.close()
