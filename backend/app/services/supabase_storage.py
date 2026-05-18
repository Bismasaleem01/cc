import os
import re
import uuid
from typing import Optional, Tuple

import requests
from fastapi import HTTPException, UploadFile


def _require_supabase() -> Tuple[str, str, str]:
    project_url = os.getenv("SUPABASE_URL", "").rstrip("/")
    service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    bucket = os.getenv("SUPABASE_STORAGE_BUCKET", "medical-records")

    if not project_url:
        raise HTTPException(status_code=500, detail="SUPABASE_URL is missing in backend/.env.")
    if not service_key:
        raise HTTPException(
            status_code=500,
            detail="SUPABASE_SERVICE_ROLE_KEY is missing in backend/.env.",
        )
    if not bucket:
        raise HTTPException(
            status_code=500,
            detail="SUPABASE_STORAGE_BUCKET is missing in backend/.env.",
        )

    return project_url, service_key, bucket


def _safe_part(value: str) -> str:
    clean = re.sub(r"[^a-zA-Z0-9_.-]+", "_", value.strip().lower())
    return clean.strip("._") or "record"


def _headers(service_key: str, content_type: Optional[str] = None) -> dict:
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
    }
    if content_type:
        headers["Content-Type"] = content_type
    return headers


def upload_medical_record(file: UploadFile, patient_email: str) -> Tuple[str, str]:
    project_url, service_key, bucket = _require_supabase()
    original_name = _safe_part(file.filename or "medical-record")
    patient_part = _safe_part(patient_email)
    object_path = f"records/{patient_part}/{uuid.uuid4().hex}_{original_name}"
    upload_url = f"{project_url}/storage/v1/object/{bucket}/{object_path}"

    try:
        response = requests.post(
            upload_url,
            headers={
                **_headers(service_key, file.content_type or "application/octet-stream"),
                "x-upsert": "false",
            },
            data=file.file,
            timeout=60,
        )
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail=f"Supabase upload failed: {exc}") from exc

    if response.status_code not in (200, 201):
        raise HTTPException(
            status_code=502,
            detail=f"Supabase upload failed: {response.text}",
        )

    storage_uri = f"supabase://{bucket}/{object_path}"
    return storage_uri, generate_signed_download_url(storage_uri)


def generate_signed_download_url(storage_uri: str) -> Optional[str]:
    if not storage_uri.startswith("supabase://"):
        return storage_uri

    project_url, service_key, bucket = _require_supabase()
    prefix = f"supabase://{bucket}/"
    if not storage_uri.startswith(prefix):
        return None

    object_path = storage_uri[len(prefix) :]
    signed_url = f"{project_url}/storage/v1/object/sign/{bucket}/{object_path}"
    try:
        response = requests.post(
            signed_url,
            headers={**_headers(service_key), "Content-Type": "application/json"},
            json={"expiresIn": 1800},
            timeout=20,
        )
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail=f"Supabase link failed: {exc}") from exc

    if response.status_code not in (200, 201):
        raise HTTPException(
            status_code=502,
            detail=f"Supabase signed link failed: {response.text}",
        )

    data = response.json()
    path = data.get("signedURL") or data.get("signedUrl")
    if not path:
        return None
    if path.startswith("http"):
        return path
    if path.startswith("/storage/v1/"):
        return f"{project_url}{path}"
    if path.startswith("/"):
        return f"{project_url}/storage/v1{path}"
    return f"{project_url}/storage/v1/{path}"
