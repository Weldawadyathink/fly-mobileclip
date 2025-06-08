from fastapi import FastAPI
import mobileclip
from pydantic import BaseModel
import torch
from PIL import Image
import re
from io import BytesIO
import requests
import time

model, _, preprocess = mobileclip.create_model_and_transforms(
    "${name}",
    pretrained="/weights/${weights_file}"
)
tokenizer = mobileclip.get_tokenizer("${name}")

device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device)
model.eval()

print(f"🤖 Model loaded")


def embedImageUrl(imageUrl):
    print(f"Downloading {imageUrl}")
    image = Image.open(BytesIO(requests.get(imageUrl).content))
    if image.mode in ('RGBA', 'LA', 'P'):
        image = image.convert('RGB')
    with torch.no_grad(), torch.cuda.amp.autocast():
        image = preprocess(image).unsqueeze(0)
        embedding = model.encode_image(image)
        embedding /= embedding.norm(dim=-1, keepdim=True)
        embedding = embedding.cpu().numpy().tolist()[0]
        return {
            "input": imageUrl,
            "embedding": embedding,
        }


def embedText(text):
    print(f"Embedding text {text}")
    with torch.no_grad(), torch.cuda.amp.autocast():
        tokens = tokenizer([text])
        embedding = model.encode_text(tokens)
        embedding /= embedding.norm(dim=-1, keepdim=True)
        embedding = embedding.cpu().numpy().tolist()[0]
        return {
            "input": text,
            "embedding": embedding,
        }


app = FastAPI()


class Input(BaseModel):
  inputs: str


@app.post("/predictions")
async def predict(input: Input):
    print(f"Running predictions for {input.inputs}")
    start_time = time.perf_counter()

    returnval = []

    for line in input.inputs.strip().splitlines():
        line = line.strip()
        if re.match("^https?://", line):
            returnval.append(embedImageUrl(line))
        else:
            result = embedText(line)
            returnval.append(result)
    
    duration = time.perf_counter() - start_time
    print(f"Embedding completed in {duration: .1f} second")
    return returnval


@app.get("/")
async def hello_fly():
    return 'hello from fly.io'

