from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session
from app.models.database import get_db
from app.services.chatbot import HealthAssistant
from app.utils.dependencies import get_current_user, require_roles

router = APIRouter()

class ChatMessage(BaseModel):
    message: str

class ChatResponse(BaseModel):
    message: str

@router.post("/message", response_model=ChatResponse)
def chat(message_in: ChatMessage,
         db: Session = Depends(get_db),
         current_user: dict = Depends(require_roles("patient"))):

    try:
        assistant = HealthAssistant(db, patient_email=current_user["email"])
        response_text = assistant.generate_response(message_in.message)
        return ChatResponse(message=response_text)
    except ValueError:
        raise HTTPException(status_code=404, detail="Patient not found")
