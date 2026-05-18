from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship  # <- ADD THIS
from .database import Base

class Appointment(Base):
    __tablename__ = "appointments"
    
    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    doctor_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    appointment_time = Column(DateTime, nullable=False)
    status = Column(String, default="scheduled")  # scheduled / completed / canceled
    appointment_type = Column(String, default="video")  # video / physical
    billing_amount = Column(Integer, default=30)
    payment_status = Column(String, default="unpaid")  # unpaid / paid
    notes = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)

    # Relationships
    patient = relationship("User", foreign_keys=[patient_id])
    doctor = relationship("User", foreign_keys=[doctor_id])
