"""Genera il sito vetrina in cinque lingue: site/{it,en,fr,de,es}/{index,privacy,termini,supporto,elimina-account}.html.

Uso: python3 site-src/build.py

Ogni pagina si scrive una volta per lingua in site-src/{lingua}/{pagina}.html: due righe iniziali (title e
description), una riga "---" e poi il <main>. Nei collegamenti alle altre pagine si scrive {base} al posto della
lingua ({base}/privacy → /en/privacy). Testata con il selettore della lingua, piè di pagina, collegamenti tra le
versioni (hreflang) e sitemap.xml li aggiunge questo script.

Gli indirizzi senza lingua (/, /privacy, /termini, /supporto, /elimina-account: quelli usati dall'app e da Google Play)
portano Caddy alla lingua del browser (intestazione Accept-Language), vedi backend/docker/Caddyfile.
"""

import html
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.join(ROOT, '..', 'site')
DOMAIN = 'https://listaspesafacile.com'

LANGS = ['it', 'en', 'fr', 'de', 'es']
LANG_NAMES = {'it': 'Italiano', 'en': 'English', 'fr': 'Français', 'de': 'Deutsch', 'es': 'Español'}
PAGES = ['index', 'privacy', 'termini', 'supporto', 'elimina-account']

# Testi comuni: menu, piè di pagina, etichette.
UI = {
    'it': {'support': 'Supporto', 'privacy': 'Privacy', 'delete': 'Elimina account', 'menu': 'Menu',
           'terms': "Condizioni d'uso", 'info': 'Informazioni', 'language': 'Lingua',
           'trademark': 'Google Play e il logo di Google Play sono marchi di Google LLC.'},
    'en': {'support': 'Support', 'privacy': 'Privacy', 'delete': 'Delete account', 'menu': 'Menu',
           'terms': "Terms of use", 'info': 'Information', 'language': 'Language',
           'trademark': 'Google Play and the Google Play logo are trademarks of Google LLC.'},
    'fr': {'support': 'Assistance', 'privacy': 'Confidentialité', 'delete': 'Supprimer le compte', 'menu': 'Menu',
           'terms': "Conditions d'utilisation", 'info': 'Informations', 'language': 'Langue',
           'trademark': 'Google Play et le logo Google Play sont des marques de Google LLC.'},
    'de': {'support': 'Hilfe', 'privacy': 'Datenschutz', 'delete': 'Konto löschen', 'menu': 'Menü',
           'terms': "Nutzungsbedingungen", 'info': 'Informationen', 'language': 'Sprache',
           'trademark': 'Google Play und das Google Play-Logo sind Marken von Google LLC.'},
    'es': {'support': 'Soporte', 'privacy': 'Privacidad', 'delete': 'Eliminar cuenta', 'menu': 'Menú',
           'terms': "Condiciones de uso", 'info': 'Información', 'language': 'Idioma',
           'trademark': 'Google Play y el logotipo de Google Play son marcas de Google LLC.'},
}


def path(lang: str, page: str) -> str:
    return f'/{lang}/' if page == 'index' else f'/{lang}/{page}'


def read(lang: str, page: str) -> tuple[str, str, str]:
    with open(os.path.join(ROOT, lang, f'{page}.html'), encoding='utf-8') as f:
        head, body = f.read().split('\n---\n', 1)
    meta = dict(line.split(': ', 1) for line in head.splitlines())
    return meta['title'], meta['description'], body.replace('{base}', f'/{lang}').rstrip() + '\n'


def render(lang: str, page: str) -> str:
    t = UI[lang]
    title, description, main = read(lang, page)
    current = lambda p: ' aria-current="page"' if p == page else ''
    alternates = '\n'.join(
        f'  <link rel="alternate" hreflang="{other}" href="{DOMAIN}{path(other, page)}">' for other in LANGS
    )
    x_default = '/' if page == 'index' else f'/{page}'
    switcher = '\n'.join(
        f'        <a href="{path(other, page)}" hreflang="{other}" lang="{other}" title="{LANG_NAMES[other]}"'
        f'{" aria-current=\"true\"" if other == lang else ""}>{other.upper()}</a>'
        for other in LANGS
    )
    script = '\n  <script src="/elimina-account.js" defer></script>' if page == 'elimina-account' else ''
    return f'''<!doctype html>
<html lang="{lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title}</title>
  <meta name="description" content="{html.escape(description, quote=True)}">
  <link rel="canonical" href="{DOMAIN}{path(lang, page)}">
{alternates}
  <link rel="alternate" hreflang="x-default" href="{DOMAIN}{x_default}">
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="/style.css">{script}
</head>
<body>
  <header class="testata">
    <div class="contenitore">
      <a class="marchio" href="/{lang}/"><img src="/favicon.svg" alt="" width="32" height="32">Lista Spesa Facile</a>
      <nav class="menu" aria-label="{t['menu']}">
        <a href="/{lang}/supporto"{current('supporto')}>{t['support']}</a>
        <a href="/{lang}/privacy"{current('privacy')}>{t['privacy']}</a>
      </nav>
      <nav class="lingue" aria-label="{t['language']}">
{switcher}
      </nav>
    </div>
  </header>

{main}
  <footer class="piede">
    <div class="contenitore">
      <span>© 2026 Lista Spesa Facile</span>
      <nav aria-label="{t['info']}">
        <a href="/{lang}/supporto">{t['support']}</a>
        <a href="/{lang}/privacy">{t['privacy']}</a>
        <a href="/{lang}/termini">{t['terms']}</a>
        <a href="/{lang}/elimina-account">{t['delete']}</a>
      </nav>
      <p class="marchi">{t['trademark']}</p>
    </div>
  </footer>
</body>
</html>
'''


def main() -> None:
    for lang in LANGS:
        os.makedirs(os.path.join(SITE, lang), exist_ok=True)
        for page in PAGES:
            with open(os.path.join(SITE, lang, f'{page}.html'), 'w', encoding='utf-8') as f:
                f.write(render(lang, page))
    urls = '\n'.join(f'  <url><loc>{DOMAIN}{path(lang, page)}</loc></url>' for page in PAGES for lang in LANGS)
    with open(os.path.join(SITE, 'sitemap.xml'), 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n'
                '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + urls + '\n</urlset>\n')
    print(f'{len(LANGS) * len(PAGES)} pagine in {len(LANGS)} lingue')


if __name__ == '__main__':
    main()
