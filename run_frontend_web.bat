@echo off
cd /d C:\Projects\SmartHealthcareApp\frontend\smart_healthcare\build\web
C:\Projects\SmartHealthcareApp\.venv\Scripts\python.exe -m http.server 8080 --bind 0.0.0.0
