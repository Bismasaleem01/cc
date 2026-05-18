from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.models.database import Base, engine

# Import models so SQLAlchemy registers them before create_all.
from app.models.appointment import Appointment
from app.models.billing import Bill
from app.models.chat_history import ChatHistory
from app.models.record import Record
from app.models.user import User

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Smart Healthcare API")


@app.get("/health", tags=["Health"])
def health_check():
    return {"status": "ok"}


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from app.api.routes import appointments, auth, billing, chatbot, records, video

app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
app.include_router(appointments.router, prefix="/appointments", tags=["Appointments"])
app.include_router(records.router, prefix="/records", tags=["Records"])
app.include_router(video.router, prefix="/video", tags=["Video"])
app.include_router(chatbot.router, prefix="/chatbot", tags=["Chatbot"])
app.include_router(billing.router, prefix="/billing", tags=["Billing"])
