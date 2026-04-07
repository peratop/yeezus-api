from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.routers import usuarios
from app.database import engine
from app.models.base import Base
import app.models.usuarios 

@asynccontextmanager
async def lifespan(app: FastAPI):
    #conectar no banco e criar as tabelas que ainda nao existem
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield #o servidor fica rodando aqui


app = FastAPI(
    tittle="Yeezus API",
    description="Assistente Financeiro com IA",
    version="0.1.0",
    lifespan=lifespan
)

@app.get("/")
def read_root():
    return {"status": "online", "message": "Yeezus backend is running!"}

app.include_router(usuarios.router)
