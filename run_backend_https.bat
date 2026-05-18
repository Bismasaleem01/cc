@echo off
cd /d C:\Projects\SmartHealthcareApp\backend
C:\Projects\SmartHealthcareApp\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8443 --ssl-keyfile C:\Projects\SmartHealthcareApp\certs\local-key.pem --ssl-certfile C:\Projects\SmartHealthcareApp\certs\local-cert.pem
