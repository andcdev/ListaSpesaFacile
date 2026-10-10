"""Controllo delle foto: POST /controlla con il campo "image" → {"sexual": 0..1, "violence": 0..1}.

Le soglie oltre le quali la foto è rifiutata le decide Laravel (config services.moderation).
"""

import io
import os

import torch
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image, ImageOps
from transformers import CLIPModel, CLIPProcessor, pipeline

torch.set_num_threads(int(os.environ.get('THREADS', '2')))
Image.MAX_IMAGE_PIXELS = 60_000_000

nsfw = pipeline('image-classification', model='/modelli/nsfw')
clip = CLIPModel.from_pretrained('/modelli/clip').eval()
processor = CLIPProcessor.from_pretrained('/modelli/clip')

# CLIP sceglie la descrizione più vicina alla foto: il punteggio di violenza è la probabilità sommata di quelle
# violente. Tra quelle normali ci sono le foto tipiche di un'app della spesa (carne cruda, pesce, coltelli da cucina,
# salsa di pomodoro, vino rosso) che altrimenti somiglierebbero al sangue.
VIOLENCE = [
    'a photo of graphic violence',
    'a photo of a person bleeding from a wound',
    'a gory photo with blood and injuries',
    'a photo of a dead body',
    'a photo of someone being beaten or attacked',
    'a photo of a person threatening someone with a gun or a knife',
    'a photo of self-harm',
]
NORMAL = [
    'a photo of groceries',
    'a photo of a food product package',
    'a photo of fruit and vegetables',
    'a photo of raw meat at the butcher',
    'a photo of a raw steak',
    'a photo of fish at the market',
    'a photo of tomato sauce',
    'a photo of a plate of food',
    'a photo of a kitchen knife on a cutting board',
    'a photo of a supermarket shelf',
    'a photo of a bottle of red wine',
    'a photo of a person smiling',
    'a selfie',
    'a photo of a family',
    'a photo of a pet',
    'a photo of a receipt',
    'a screenshot of a phone',
    'a photo of a room',
    'a photo of a landscape',
    'a drawing or a cartoon',
    'a diagram or a chart',
    'a document or a page with text',
    'a photo of a cooked meal',
    'a photo of household cleaning products',
    'a photo of people having dinner together',
    'a photo of a child playing',
    'a photo of plants or flowers',
    'a photo of a street or a car',
    'a photo of a building',
    'a photo of a shopping cart',
]

with torch.no_grad():
    _text = processor(text=VIOLENCE + NORMAL, return_tensors='pt', padding=True)
    TEXT_FEATURES = clip.get_text_features(**_text)
    TEXT_FEATURES = TEXT_FEATURES / TEXT_FEATURES.norm(dim=-1, keepdim=True)

app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)


def violence_score(image: Image.Image) -> float:
    with torch.no_grad():
        features = clip.get_image_features(**processor(images=image, return_tensors='pt'))
        features = features / features.norm(dim=-1, keepdim=True)
        probs = (clip.logit_scale.exp() * features @ TEXT_FEATURES.T).softmax(dim=-1)[0]
    return float(probs[: len(VIOLENCE)].sum())


def sexual_score(image: Image.Image) -> float:
    return next((r['score'] for r in nsfw(image) if r['label'] == 'nsfw'), 0.0)


@app.post('/controlla')
async def controlla(image: UploadFile = File(...)):
    try:
        picture = Image.open(io.BytesIO(await image.read()))
        picture = ImageOps.exif_transpose(picture).convert('RGB')
    except Exception:
        raise HTTPException(status_code=422, detail='immagine non leggibile')
    picture.thumbnail((1024, 1024))
    return {'sexual': round(sexual_score(picture), 4), 'violence': round(violence_score(picture), 4)}


@app.get('/salute')
def salute():
    return {'ok': True}
