from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes import fixtures
from app.routes import predictions

app = FastAPI(
    title="Sure Predict Backend",
    version="1.0.0"
)

# CORS pentru Flutter / Browser / Swagger
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routes
app.include_router(fixtures.router)
app.include_router(predictions.router)


@app.get("/")
def root():
    return {
        "message": "Sure Predict Backend running"
    }


@app.get("/health")
def health():
    return {
        "status": "ok"
    }
