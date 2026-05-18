from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Dict, List
from app.models.appointment import Appointment
from app.models.database import get_db
from app.models.user import User
from app.utils.dependencies import require_roles

router = APIRouter()
waiting_calls: Dict[int, dict] = {}

class WaitingCallOut(BaseModel):
    appointment_id: int
    patient_email: str
    doctor_email: str
    appointment_time: datetime

# Connection Manager for WebSocket clients
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}
        self.last_messages: Dict[str, List[dict]] = {}

    async def connect(self, room_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.setdefault(room_id, []).append(websocket)
        for message in self.last_messages.get(room_id, []):
            await websocket.send_json(message)

    def disconnect(self, room_id: str, websocket: WebSocket):
        if room_id in self.active_connections and websocket in self.active_connections[room_id]:
            self.active_connections[room_id].remove(websocket)
        if room_id in self.active_connections and not self.active_connections[room_id]:
            del self.active_connections[room_id]

    async def broadcast(self, room_id: str, sender: WebSocket, message: dict):
        """
        Broadcast signaling messages to other clients in the same appointment room.
        """
        if message.get("type") in ["ready", "offer"]:
            history = self.last_messages.setdefault(room_id, [])
            history.append(message)
            self.last_messages[room_id] = history[-4:]
        for connection in self.active_connections.get(room_id, []):
            if connection is not sender:
                await connection.send_json(message)

# Initialize manager
manager = ConnectionManager()

def _get_accessible_appointment(appointment_id: int, db: Session, current_user: dict) -> tuple[Appointment, User, User]:
    appointment = db.query(Appointment).filter(Appointment.id == appointment_id).first()
    if not appointment:
        raise HTTPException(status_code=404, detail="Appointment not found")

    patient = db.query(User).filter(User.id == appointment.patient_id).first()
    doctor = db.query(User).filter(User.id == appointment.doctor_id).first()
    if current_user["role"] == "patient" and patient.email != current_user["email"]:
        raise HTTPException(status_code=403, detail="Access denied")
    if current_user["role"] == "doctor" and doctor.email != current_user["email"]:
        raise HTTPException(status_code=403, detail="Access denied")
    return appointment, patient, doctor

@router.post("/waiting/{appointment_id}", response_model=WaitingCallOut)
def mark_waiting(appointment_id: int,
                 db: Session = Depends(get_db),
                 current_user: dict = Depends(require_roles("doctor", "patient"))):
    appointment, patient, doctor = _get_accessible_appointment(appointment_id, db, current_user)
    if appointment.appointment_type != "video":
        raise HTTPException(status_code=400, detail="Only video appointments can start a call")
    if appointment.status != "scheduled":
        raise HTTPException(status_code=400, detail="Appointment is not scheduled")
    waiting_calls[appointment_id] = {
        "appointment_id": appointment.id,
        "patient_email": patient.email,
        "doctor_email": doctor.email,
        "appointment_time": appointment.appointment_time,
    }
    return WaitingCallOut(**waiting_calls[appointment_id])

@router.get("/waiting", response_model=List[WaitingCallOut])
def list_waiting(db: Session = Depends(get_db),
                 current_user: dict = Depends(require_roles("doctor", "patient"))):
    active = []
    for appointment_id, call in list(waiting_calls.items()):
        appointment = db.query(Appointment).filter(Appointment.id == appointment_id).first()
        if not appointment or appointment.status != "scheduled":
            waiting_calls.pop(appointment_id, None)
            continue
        if current_user["role"] == "doctor" and call["doctor_email"] == current_user["email"]:
            active.append(WaitingCallOut(**call))
        if current_user["role"] == "patient" and call["patient_email"] == current_user["email"]:
            active.append(WaitingCallOut(**call))
    return active

@router.delete("/waiting/{appointment_id}")
def clear_waiting(appointment_id: int,
                  db: Session = Depends(get_db),
                  current_user: dict = Depends(require_roles("doctor", "patient"))):
    _get_accessible_appointment(appointment_id, db, current_user)
    waiting_calls.pop(appointment_id, None)
    return {"message": "Waiting call cleared"}

# WebSocket endpoint for video call signaling
@router.websocket("/ws/video/{room_id}")
async def websocket_endpoint(room_id: str, websocket: WebSocket):
    """
    Each client connects here to exchange signaling data (SDP, ICE candidates)
    Frontend handles actual video/audio streams.
    """
    await manager.connect(room_id, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            await manager.broadcast(room_id, websocket, data)
    except WebSocketDisconnect:
        manager.disconnect(room_id, websocket)
