from pydantic import BaseModel, EmailStr
from datetime import datetime

#cria um usuario aqui
class UsuarioCreate(BaseModel):
    nome: str
    email: EmailStr
    senha: str

#retornar os dados sem devolver a senha
class UsuarioResponse(BaseModel):
    id: int
    nome: str
    email: EmailStr
    data_criacao: datetime

    class Config:
        from_atributes = True #utilizado para ler dados do sqlalchemy