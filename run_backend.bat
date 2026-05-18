@echo off
cd /d C:\Projects\SmartHealthcareApp\backend
C:\Projects\SmartHealthcareApp\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
