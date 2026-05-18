from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from .database import Base
from datetime import datetime

class ChatHistory(Base):
    __tablename__ = "chat_history"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    message = Column(String, nullable=False)        # Patient message
    response = Column(String, nullable=False)       # Chatbot response
    timestamp = Column(DateTime, default=datetime.utcnow)