from datetime import datetime
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from app.models.appointment import Appointment
from app.models.billing import Bill
from app.models.database import get_db
from app.models.user import User
from app.utils.dependencies import require_roles

router = APIRouter()


class BillOut(BaseModel):
    id: int
    appointment_id: int
    patient_email: EmailStr
    doctor_email: EmailStr
    amount: int
    status: str
    description: str
    created_at: datetime
    paid_at: datetime | None = None


def _to_out(bill: Bill, patient: User, doctor: User) -> BillOut:
    return BillOut(
        id=bill.id,
        appointment_id=bill.appointment_id,
        patient_email=patient.email,
        doctor_email=doctor.email,
        amount=bill.amount,
        status=bill.status,
        description=bill.description,
        created_at=bill.created_at,
        paid_at=bill.paid_at,
    )


def _ensure_missing_bills(db: Session) -> None:
    appointments = db.query(Appointment).filter(Appointment.status != "canceled").all()
    changed = False
    for appointment in appointments:
        existing = db.query(Bill).filter(Bill.appointment_id == appointment.id).first()
        if existing:
            appointment.payment_status = existing.status
            continue

        doctor = db.query(User).filter(User.id == appointment.doctor_id).first()
        appointment_type = appointment.appointment_type or "video"
        amount = appointment.billing_amount or (30 if appointment_type == "video" else 50)
        bill = Bill(
            appointment_id=appointment.id,
            patient_id=appointment.patient_id,
            doctor_id=appointment.doctor_id,
            amount=amount,
            status=appointment.payment_status if appointment.payment_status == "paid" else "unpaid",
            description=f"{appointment_type.title()} consultation with {doctor.name if doctor else 'doctor'}",
        )
        appointment.payment_status = bill.status
        db.add(bill)
        changed = True
    if changed:
        db.commit()


@router.get("/", response_model=List[BillOut])
def list_bills(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_roles("patient", "doctor")),
):
    _ensure_missing_bills(db)
    query = db.query(Bill)
    if current_user["role"] == "patient":
        user = db.query(User).filter(User.email == current_user["email"]).first()
        query = query.filter(Bill.patient_id == user.id)
    else:
        user = db.query(User).filter(User.email == current_user["email"]).first()
        query = query.filter(Bill.doctor_id == user.id)

    bills = query.order_by(Bill.created_at.desc()).all()
    result = []
    for bill in bills:
        patient = db.query(User).filter(User.id == bill.patient_id).first()
        doctor = db.query(User).filter(User.id == bill.doctor_id).first()
        result.append(_to_out(bill, patient, doctor))
    return result


@router.post("/{bill_id}/pay", response_model=BillOut)
def pay_bill(
    bill_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_roles("patient")),
):
    bill = db.query(Bill).filter(Bill.id == bill_id).first()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")
    patient = db.query(User).filter(User.id == bill.patient_id).first()
    doctor = db.query(User).filter(User.id == bill.doctor_id).first()
    if patient.email != current_user["email"]:
        raise HTTPException(status_code=403, detail="Access denied")

    bill.status = "paid"
    bill.paid_at = datetime.utcnow()
    appointment = db.query(Appointment).filter(Appointment.id == bill.appointment_id).first()
    if appointment:
        appointment.payment_status = "paid"
    db.commit()
    db.refresh(bill)
    return _to_out(bill, patient, doctor)
