from fastapi import APIRouter, HTTPException, Depends, File, Form, UploadFile
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional, List

from app.models.database import get_db
from app.models.record import Record
from app.models.user import User
from app.services.supabase_storage import (
    generate_signed_download_url,
    upload_medical_record,
)
from app.utils.dependencies import get_current_user, require_roles

router = APIRouter()

class RecordCreate(BaseModel):
    patient_email: EmailStr
    doctor_email: Optional[EmailStr] = None
    title: str
    description: Optional[str] = None
    file_url: str

class RecordOut(BaseModel):
    id: int
    patient_name: str
    patient_email: EmailStr
    doctor_email: Optional[EmailStr] = None
    title: str
    description: Optional[str] = None
    file_url: str
    download_url: Optional[str] = None
    uploaded_at: datetime


def _find_patient_or_404(db: Session, patient_email: str) -> User:
    patient = db.query(User).filter(User.email == patient_email).first()
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    return patient


def _find_doctor_id_or_404(db: Session, doctor_email: Optional[str]) -> Optional[int]:
    if not doctor_email:
        return None
    doctor = db.query(User).filter(User.email == doctor_email).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor not found")
    return doctor.id


def _authorize_record_owner(current_user: dict, patient_email: str, doctor_email: Optional[str]):
    if current_user["role"] == "patient" and current_user["email"] != patient_email:
        raise HTTPException(status_code=403, detail="Patients can only create their own records")
    if current_user["role"] == "doctor" and doctor_email and current_user["email"] != doctor_email:
        raise HTTPException(status_code=403, detail="Doctors can only create records for themselves")


def _record_out(
    record: Record,
    patient_name: str,
    patient_email: str,
    doctor_email: Optional[str],
) -> RecordOut:
    download_url = generate_signed_download_url(record.file_url)
    return RecordOut(
        id=record.id,
        patient_name=patient_name,
        patient_email=patient_email,
        doctor_email=doctor_email,
        title=record.title,
        description=record.description,
        file_url=record.file_url,
        download_url=download_url,
        uploaded_at=record.uploaded_at,
    )

# Create record
@router.post("/", response_model=RecordOut)
def create_record(record: RecordCreate,
                  db: Session = Depends(get_db),
                  current_user: dict = Depends(require_roles("doctor", "patient"))):

    _authorize_record_owner(current_user, record.patient_email, record.doctor_email)
    patient = _find_patient_or_404(db, record.patient_email)
    doctor_id = _find_doctor_id_or_404(db, record.doctor_email)

    new_record = Record(
        patient_id=patient.id,
        doctor_id=doctor_id,
        title=record.title,
        description=record.description,
        file_url=record.file_url,
        uploaded_at=datetime.utcnow()
    )
    db.add(new_record)
    db.commit()
    db.refresh(new_record)

    return _record_out(new_record, patient.name, patient.email, record.doctor_email)


@router.post("/upload", response_model=RecordOut)
def upload_record(
    patient_email: EmailStr = Form(...),
    doctor_email: Optional[EmailStr] = Form(None),
    title: str = Form(...),
    description: Optional[str] = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_roles("doctor", "patient")),
):
    _authorize_record_owner(current_user, patient_email, doctor_email)
    patient = _find_patient_or_404(db, patient_email)
    doctor_id = _find_doctor_id_or_404(db, doctor_email)
    clean_title = title.strip()
    if not clean_title:
        raise HTTPException(status_code=400, detail="Record title is required")

    storage_uri, _download_url = upload_medical_record(file, patient.email)
    new_record = Record(
        patient_id=patient.id,
        doctor_id=doctor_id,
        title=clean_title,
        description=description,
        file_url=storage_uri,
        uploaded_at=datetime.utcnow(),
    )
    db.add(new_record)
    db.commit()
    db.refresh(new_record)

    return _record_out(new_record, patient.name, patient.email, doctor_email)


@router.get("/{record_id}/download")
def get_record_download_link(
    record_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_roles("doctor", "patient")),
):
    record = db.query(Record).filter(Record.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Record not found")

    patient = db.query(User).filter(User.id == record.patient_id).first()
    doctor = db.query(User).filter(User.id == record.doctor_id).first() if record.doctor_id else None
    doctor_email = doctor.email if doctor else None
    if current_user["role"] == "patient" and patient.email != current_user["email"]:
        raise HTTPException(status_code=403, detail="You cannot access this record")
    if current_user["role"] == "doctor" and doctor_email and doctor_email != current_user["email"]:
        raise HTTPException(status_code=403, detail="You cannot access this record")

    return {"download_url": generate_signed_download_url(record.file_url)}

# Get all records for current user
@router.get("/", response_model=List[RecordOut])
def list_records(db: Session = Depends(get_db),
                 current_user: dict = Depends(require_roles("doctor", "patient"))):

    records = db.query(Record).all()
    result = []
    for r in records:
        patient = db.query(User).filter(User.id == r.patient_id).first()
        doctor_email = None
        if r.doctor_id:
            doctor = db.query(User).filter(User.id == r.doctor_id).first()
            doctor_email = doctor.email

        if current_user["role"] == "patient" and patient.email != current_user["email"]:
            continue
        if current_user["role"] == "doctor" and doctor_email and doctor_email != current_user["email"]:
            continue

        result.append(_record_out(r, patient.name, patient.email, doctor_email))
    return result
