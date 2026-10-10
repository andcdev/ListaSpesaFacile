# Controllo delle foto caricate nell'app: nudità, contenuti sessuali e violenza, con modelli open source che girano
# qui (le foto non escono dal server). Lo usa Laravel (App\Support\ImageModeration) sulla rete interna "moderazione".
#
#   contenuti sessuali  Falconsai/nsfw_image_detection   (ViT, licenza Apache 2.0)
#   violenza            openai/clip-vit-base-patch32     (CLIP, licenza MIT) confrontato con descrizioni di testo
#
# I modelli si scaricano durante la build e restano nell'immagine: in funzione il servizio non va su Internet.
FROM python:3.12-slim

ENV PIP_NO_CACHE_DIR=1 PYTHONUNBUFFERED=1 HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1

RUN pip install torch==2.5.1 --index-url https://download.pytorch.org/whl/cpu \
 && pip install transformers==4.46.3 numpy==2.1.3 pillow==11.0.0 fastapi==0.115.6 uvicorn==0.32.1 \
    python-multipart==0.0.20

RUN HF_HUB_OFFLINE=0 python -c "\
from huggingface_hub import snapshot_download as s; \
s('Falconsai/nsfw_image_detection', local_dir='/modelli/nsfw', allow_patterns=['*.json', 'model.safetensors']); \
s('openai/clip-vit-base-patch32', local_dir='/modelli/clip', allow_patterns=['*.json', '*.txt', 'pytorch_model.bin'])"

WORKDIR /srv
COPY app.py .
RUN useradd --system --uid 10001 moderazione
USER moderazione

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/salute', timeout=4)"
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
