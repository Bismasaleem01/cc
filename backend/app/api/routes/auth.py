from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session
from app.utils.security import hash_password, verify_password, create_access_token
from app.models.database import get_db
from app.models.user import User
from app.utils.dependencies import require_roles, get_current_user
from typing import Optional, List

router = APIRouter()

# Pydantic models
class UserRegister(BaseModel):
    name: str
    email: EmailStr
    password: str
    role: str = "patient"  # patient/doctor/admin
    specialty: Optional[str] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class DoctorOut(BaseModel):
    name: str
    email: EmailStr
    specialty: Optional[str] = None

class UserOut(BaseModel):
    name: str
    email: EmailStr
    role: str
    specialty: Optional[str] = None

class ProfileUpdate(BaseModel):
    name: Optional[str] = None
    role: Optional[str] = None
    specialty: Optional[str] = None

class SpecialtyUpdate(BaseModel):
    specialty: str

# Register user
@router.post("/register")
def register(user: UserRegister, db: Session = Depends(get_db)):
    if user.role not in ["patient", "doctor", "admin"]:
        raise HTTPException(status_code=400, detail="Invalid role")
    if user.role == "doctor" and not user.specialty:
        raise HTTPException(status_code=400, detail="Doctors must set a specialty")

    existing_user = db.query(User).filter(User.email == user.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_pw = hash_password(user.password)
    new_user = User(
        name=user.name,
        email=user.email,
        hashed_password=hashed_pw,
        role=user.role,
        specialty=user.specialty if user.role == "doctor" else None
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return {
        "message": "User registered successfully",
        "user": {
            "name": new_user.name,
            "email": new_user.email,
            "role": new_user.role,
            "specialty": new_user.specialty
        }
    }

# Login user
@router.post("/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.email == user.email).first()
    if not db_user or not verify_password(user.password, db_user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access_token = create_access_token(data={"sub": db_user.email, "role": db_user.role})
    return {"access_token": access_token, "token_type": "bearer"}

@router.get("/me", response_model=UserOut)
def get_profile(db: Session = Depends(get_db),
                current_user: dict = Depends(get_current_user)):
    user = db.query(User).filter(User.email == current_user["email"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserOut(name=user.name, email=user.email, role=user.role, specialty=user.specialty)

@router.patch("/me")
def update_profile(update: ProfileUpdate,
                   db: Session = Depends(get_db),
                   current_user: dict = Depends(get_current_user)):
    user = db.query(User).filter(User.email == current_user["email"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if update.name is not None:
        name = update.name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="Name is required")
        user.name = name
    if update.role is not None:
        role = update.role.strip().lower()
        if role not in ["patient", "doctor"]:
            raise HTTPException(status_code=400, detail="Role must be patient or doctor")
        user.role = role
    if update.specialty is not None:
        specialty = update.specialty.strip()
        user.specialty = specialty or None
    if user.role == "doctor" and not user.specialty:
        raise HTTPException(status_code=400, detail="Specialty is required for doctors")
    if user.role == "patient":
        user.specialty = None

    db.commit()
    db.refresh(user)
    access_token = create_access_token(data={"sub": user.email, "role": user.role})
    return {
        "name": user.name,
        "email": user.email,
        "role": user.role,
        "specialty": user.specialty,
        "access_token": access_token,
    }

@router.get("/doctors", response_model=List[DoctorOut])
def list_doctors(db: Session = Depends(get_db),
                 current_user: dict = Depends(require_roles("patient", "doctor"))):
    doctors = (
        db.query(User)
        .filter(User.role == "doctor", User.is_active == True)
        .order_by(User.name.asc())
        .all()
    )
    return [
        DoctorOut(name=d.name, email=d.email, specialty=d.specialty or "General Practitioner")
        for d in doctors
    ]

@router.patch("/me/specialty", response_model=DoctorOut)
def update_specialty(update: SpecialtyUpdate,
                     db: Session = Depends(get_db),
                     current_user: dict = Depends(require_roles("doctor"))):
    specialty = update.specialty.strip()
    if not specialty:
        raise HTTPException(status_code=400, detail="Specialty is required")

    doctor = db.query(User).filter(User.email == current_user["email"]).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor not found")

    doctor.specialty = specialty
    db.commit()
    db.refresh(doctor)
    return DoctorOut(name=doctor.name, email=doctor.email, specialty=doctor.specialty)
