from sqlalchemy import Column, Integer, String, DateTime
from datetime import datetime, timezone
from app.models.base import Base

class Usuario(Base):
    __tablename__ = "usuario"

    id = Column (Integer, primary_key=True, index=True)
    nome = Column(String(100), nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=True)
    senha_hash = Column(String(255), nullable=False)    
    data_criacao = Column(DateTime, default=lambda: datetime.now(timezone.utc))