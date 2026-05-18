# Azure Deployment

This project is prepared for Azure Container Apps:

- Backend: FastAPI container on port `8000`
- Frontend: Nginx container on port `80`
- Images: Azure Container Registry
- Database: Azure Database for PostgreSQL Flexible Server
- Medical files: Supabase Storage

## 1. Create Azure Resources

You need these Azure resources:

- Resource group
- Azure Container Registry
- Azure Container Apps environment
- Backend Container App
- Frontend Container App
- Azure Database for PostgreSQL Flexible Server

Use these container app settings:

Backend:

- Image: temporary image first, then GitHub Actions will update it
- Target port: `8000`
- External ingress: enabled

Frontend:

- Image: temporary image first, then GitHub Actions will update it
- Target port: `80`
- External ingress: enabled

## 2. GitHub Repository Secrets

Add these in GitHub:

`Settings -> Secrets and variables -> Actions -> New repository secret`

Required Azure secrets:

```text
AZURE_CREDENTIALS
AZURE_RESOURCE_GROUP
AZURE_ACR_NAME
AZURE_ACR_LOGIN_SERVER
AZURE_BACKEND_APP
AZURE_FRONTEND_APP
AZURE_BACKEND_URL
```

Required backend application secrets:

```text
DATABASE_URL
SECRET_KEY
GEMINI_API_KEY
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
SUPABASE_STORAGE_BUCKET
```

`AZURE_BACKEND_URL` should be the public backend Container App URL, for example:

```text
https://smart-healthcare-api.whitepond-123456.eastus.azurecontainerapps.io
```

`DATABASE_URL` should point to Azure PostgreSQL. Example format:

```text
postgresql://db_user:db_password@server-name.postgres.database.azure.com:5432/smart_healthcare?sslmode=require
```

## 3. Create AZURE_CREDENTIALS

On a machine with Azure CLI installed:

```bash
az login
az account set --subscription "<subscription-id>"
az ad sp create-for-rbac \
  --name "smart-healthcare-github-actions" \
  --role contributor \
  --scopes /subscriptions/<subscription-id>/resourceGroups/<resource-group-name> \
  --sdk-auth
```

Copy the JSON output into the GitHub secret named `AZURE_CREDENTIALS`.

## 4. Deploy

After secrets are added, push to `main` or manually run:

`Actions -> Deploy to Azure -> Run workflow`

The workflow will:

1. Log in to Azure.
2. Build backend and frontend Docker images.
3. Push images to Azure Container Registry.
4. Update the backend Container App.
5. Update the frontend Container App.

## 5. Important Notes

- Camera and microphone require HTTPS. Azure Container Apps provides HTTPS URLs.
- Keep `SUPABASE_SERVICE_ROLE_KEY` only in backend secrets.
- Do not commit `backend/.env`.
- If you change the backend Container App URL, update `AZURE_BACKEND_URL` and rerun deployment so the frontend is rebuilt with the correct API URL.
