from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.schemas.usuarios import UsuarioCreate, UsuarioResponse
from app.models.usuarios import Usuario

router = APIRouter(prefix="/usuarios", tags=["Usuários"])

@router.post("/", response_model=UsuarioResponse)
async def criar_usuario (usuario: UsuarioCreate, db: AsyncSession = Depends(get_db)):
    #passo a passo: pega o schema e converte pro modelo que usei do sqlAlchemy
    novo_usuario = Usuario(
        nome=usuario.nome,
        email=usuario.email,
        senha_hash=usuario.senha #criptografar quando der
    )

    #adiciona a sessao do banco e comita a transação
    db.add(novo_usuario)
    await db.commit()

    # atualiza o objeto para pegar o id criado pelo sql
    await db.refresh(novo_usuario)

    #retorna o usuario criado
    return novo_usuario