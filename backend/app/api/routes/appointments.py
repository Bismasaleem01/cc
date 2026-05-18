from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional, List

from app.models.database import get_db
from app.models.appointment import Appointment
from app.models.billing import Bill
from app.models.user import User
from app.utils.dependencies import get_current_user, require_roles

router = APIRouter()

# Pydantic models
class AppointmentCreate(BaseModel):
    patient_email: EmailStr
    doctor_email: EmailStr
    appointment_time: datetime
    appointment_type: str = "video"
    notes: Optional[str] = None

class AppointmentOut(BaseModel):
    id: int
    patient_email: EmailStr
    doctor_email: EmailStr
    appointment_time: datetime
    status: str
    appointment_type: str
    billing_amount: int
    payment_status: str
    can_join_video: bool
    notes: Optional[str] = None

class AppointmentUpdate(BaseModel):
    appointment_time: Optional[datetime] = None
    appointment_type: Optional[str] = None
    status: Optional[str] = None
    notes: Optional[str] = None

def _billing_for(appointment_type: str) -> int:
    return 30 if appointment_type == "video" else 50

def _validate_type(appointment_type: str):
    if appointment_type not in ["video", "physical"]:
        raise HTTPException(status_code=400, detail="Appointment type must be video or physical")

def _to_out(a: Appointment, patient: User, doctor: User) -> AppointmentOut:
    appointment_type = a.appointment_type or "video"
    return AppointmentOut(
        id=a.id,
        patient_email=patient.email,
        doctor_email=doctor.email,
        appointment_time=a.appointment_time,
        status=a.status,
        appointment_type=appointment_type,
        billing_amount=a.billing_amount or _billing_for(appointment_type),
        payment_status=a.payment_status or "unpaid",
        can_join_video=(
            appointment_type == "video"
            and a.status == "scheduled"
            and datetime.now() >= a.appointment_time
        ),
        notes=a.notes
    )

# Create appointment
@router.post("/", response_model=AppointmentOut)
def create_appointment(appt: AppointmentCreate,
                       db: Session = Depends(get_db),
                       current_user: dict = Depends(require_roles("doctor", "patient"))):
    
    # Role-based restrictions
    if current_user["role"] == "patient" and current_user["email"] != appt.patient_email:
        raise HTTPException(status_code=403, detail="Patients can only create their own appointments")
    if current_user["role"] == "doctor" and current_user["email"] != appt.doctor_email:
        raise HTTPException(status_code=403, detail="Doctors can only create their own appointments")
    _validate_type(appt.appointment_type)

    patient = db.query(User).filter(User.email == appt.patient_email).first()
    doctor = db.query(User).filter(User.email == appt.doctor_email).first()
    if not patient or not doctor:
        raise HTTPException(status_code=404, detail="Patient or Doctor not found")
    if current_user["role"] == "patient":
        unpaid = db.query(Bill).filter(Bill.patient_id == patient.id, Bill.status == "unpaid").first()
        if unpaid:
            raise HTTPException(
                status_code=402,
                detail="Please pay your pending bill before booking another appointment."
            )

    new_appt = Appointment(
        patient_id=patient.id,
        doctor_id=doctor.id,
        appointment_time=appt.appointment_time,
        appointment_type=appt.appointment_type,
        billing_amount=_billing_for(appt.appointment_type),
        payment_status="unpaid",
        notes=appt.notes,
        status="scheduled"
    )
    db.add(new_appt)
    db.commit()
    db.refresh(new_appt)
    bill = Bill(
        appointment_id=new_appt.id,
        patient_id=patient.id,
        doctor_id=doctor.id,
        amount=new_appt.billing_amount,
        status="unpaid",
        description=f"{appt.appointment_type.title()} consultation with {doctor.name}",
    )
    db.add(bill)
    db.commit()

    return _to_out(new_appt, patient, doctor)

# Get all appointments for current user
@router.get("/", response_model=List[AppointmentOut])
def list_appointments(db: Session = Depends(get_db),
                      current_user: dict = Depends(require_roles("doctor", "patient"))):
    
    appts = db.query(Appointment).all()
    result = []
    for a in appts:
        patient = db.query(User).filter(User.id == a.patient_id).first()
        doctor = db.query(User).filter(User.id == a.doctor_id).first()

        if current_user["role"] == "patient" and patient.email != current_user["email"]:
            continue
        if current_user["role"] == "doctor" and doctor.email != current_user["email"]:
            continue

        result.append(_to_out(a, patient, doctor))
    return result

# Get single appointment by ID
@router.get("/{appointment_id}", response_model=AppointmentOut)
def get_appointment(appointment_id: int,
                    db: Session = Depends(get_db),
                    current_user: dict = Depends(require_roles("doctor", "patient"))):

    a = db.query(Appointment).filter(Appointment.id == appointment_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="Appointment not found")

    patient = db.query(User).filter(User.id == a.patient_id).first()
    doctor = db.query(User).filter(User.id == a.doctor_id).first()

    # Role check
    if current_user["role"] == "patient" and patient.email != current_user["email"]:
        raise HTTPException(status_code=403, detail="Access denied")
    if current_user["role"] == "doctor" and doctor.email != current_user["email"]:
        raise HTTPException(status_code=403, detail="Access denied")

    return _to_out(a, patient, doctor)

@router.patch("/{appointment_id}", response_model=AppointmentOut)
def update_appointment(appointment_id: int,
                       update: AppointmentUpdate,
                       db: Session = Depends(get_db),
                       current_user: dict = Depends(require_roles("doctor", "patient"))):
    a = db.query(Appointment).filter(Appointment.id == appointment_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="Appointment not found")

    patient = db.query(User).filter(User.id == a.patient_id).first()
    doctor = db.query(User).filter(User.id == a.doctor_id).first()
    if current_user["role"] == "patient" and patient.email != current_user["email"]:
        raise HTTPException(status_code=403, detail="Access denied")
    if current_user["role"] == "doctor" and doctor.email != current_user["email"]:
        raise HTTPException(status_code=403, detail="Access denied")

    if update.appointment_time is not None:
        a.appointment_time = update.appointment_time
    if update.appointment_type is not None:
        _validate_type(update.appointment_type)
        a.appointment_type = update.appointment_type
        a.billing_amount = _billing_for(update.appointment_type)
        bill = db.query(Bill).filter(Bill.appointment_id == a.id).first()
        if bill and bill.status == "unpaid":
            bill.amount = a.billing_amount
            bill.description = f"{update.appointment_type.title()} consultation with {doctor.name}"
    if update.notes is not None:
        a.notes = update.notes
    if update.status is not None:
        if update.status not in ["scheduled", "completed", "canceled"]:
            raise HTTPException(status_code=400, detail="Invalid appointment status")
        a.status = update.status

    db.commit()
    db.refresh(a)
    return _to_out(a, patient, doctor)
