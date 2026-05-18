import os
from typing import List
from sqlalchemy.orm import Session
from app.models.user import User
from app.models.chat_history import ChatHistory
from app.models.record import Record
from dotenv import load_dotenv
from google.api_core import exceptions as google_exceptions
import google.generativeai as genai

load_dotenv()

class HealthAssistant:
    def __init__(self, db: Session, patient_email: str):
        self.db = db
        self.patient = db.query(User).filter(User.email == patient_email).first()
        if not self.patient:
            raise ValueError("Patient not found")
        self.patient_id = self.patient.id

        self.model = None
        api_key = os.getenv("GEMINI_API_KEY")
        if api_key:
            genai.configure(api_key=api_key)
            model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")
            self.model = genai.GenerativeModel(model_name)

    def _get_patient_context(self) -> str:
        """Fetch patient's medical records to build a personalized context."""
        records = self.db.query(Record).filter(Record.patient_id == self.patient_id).all()
        if not records:
            return "The patient has no medical records on file yet."
        
        context_lines = []
        for r in records:
            context_lines.append(f"- {r.title} (Date: {r.uploaded_at.date()}): {r.description}")
        return "\n".join(context_lines)

    def _get_chat_history(self, limit: int = 4) -> List[dict]:
        """Retrieve last N messages for conversation memory formatted for Gemini."""
        history = (
            self.db.query(ChatHistory)
            .filter(ChatHistory.patient_id == self.patient_id)
            .order_by(ChatHistory.timestamp.desc())
            .limit(limit)
            .all()
        )
        
        messages = []
        for h in reversed(history):
            messages.append({"role": "user", "parts": [h.message]})
            messages.append({"role": "model", "parts": [h.response]})
        return messages

    def generate_response(self, message: str) -> str:
        """
        Generate an intelligent, personalized response using Google Gemini.
        """
        if not self.model:
            final_answer = (
                "The AI health assistant is not configured yet. Please add a GEMINI_API_KEY "
                "on the backend, then restart the server."
            )
            self._save_chat_turn(message, final_answer)
            return final_answer

        # Build the system prompt
        medical_records_summary = self._get_patient_context()
        
        system_instruction = f"""
        You are a highly advanced, compassionate, and personalized AI Health Assistant.
        You are currently assisting a patient named {self.patient.name}.
        
        Here is the patient's medical record summary from their cloud storage:
        {medical_records_summary}
        
        Instructions:
        1. Answer the patient's health questions politely and professionally.
        2. If they ask about their health or records, reference the medical record summary provided above.
        3. Always remind them that you are an AI and they should consult their human doctor for serious conditions.
        4. Keep your answers concise, clear, and easy to read.
        """

        try:
            # Create a chat session with history
            chat = self.model.start_chat(history=self._get_chat_history())
            
            # Prepend the system instruction to the latest message so the AI understands its persona and context
            full_prompt = f"System Context:\n{system_instruction}\n\nPatient Message: {message}"
            
            response = chat.send_message(full_prompt)
            final_answer = response.text
        except google_exceptions.ResourceExhausted:
            final_answer = (
                "The AI health assistant is temporarily unavailable because the Gemini API quota "
                "for this key has been reached. Please try again later or use a key/project with available quota."
            )
        except google_exceptions.NotFound:
            final_answer = (
                "The configured Gemini model is not available for this API key. Please update GEMINI_MODEL "
                "in the backend .env file."
            )
        except google_exceptions.PermissionDenied:
            final_answer = (
                "The Gemini API key was rejected. Please check that GEMINI_API_KEY is valid and that the "
                "Gemini API is enabled for its Google Cloud project."
            )
        except Exception as e:
            print(f"Gemini API Error: {e}")
            final_answer = "I apologize, but my core AI systems are currently unavailable. Please check your API key or try again later."

        self._save_chat_turn(message, final_answer)
        return final_answer

    def _save_chat_turn(self, message: str, final_answer: str) -> None:
        # Save the interaction to the database
        chat_entry = ChatHistory(
            patient_id=self.patient_id,
            message=message,
            response=final_answer
        )
        self.db.add(chat_entry)
        self.db.commit()
