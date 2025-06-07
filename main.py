from fastapi import FastAPI
import mobileclip
from pydantic import BaseModel


model, _, preprocess = mobileclip.create_model_and_transforms(
    "mobileclip_s0",
    pretrained="/weights/mobileclip_s0.pt"
)
tokenizer = mobileclip.get_tokenizer("mobileclip_s0")

device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device)
model.eval()

print(f"Model loaded")

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

class Input(BaseModel)
  inputs: str

@app.post("/predictions")
async def predict(input: Input)
    inputs = Dict(input).inputs
    print(inputs)

@app.get("/")
async def hello_fly():
    return 'hello from fly.io'

