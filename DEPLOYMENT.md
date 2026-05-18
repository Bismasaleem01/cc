# Smart Healthcare Deployment

## Local Docker Run

1. Copy the backend environment template:

   ```powershell
   Copy-Item backend\.env.example backend\.env
   ```

2. Fill `backend/.env` with real values for:

   - `SECRET_KEY`
   - `GEMINI_API_KEY`
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SUPABASE_STORAGE_BUCKET`

3. Start the stack:

   ```powershell
   docker compose up --build
   ```

4. Open:

   - Frontend: `http://localhost:8080`
   - Backend API: `http://localhost:8000/docs`
   - Health check: `http://localhost:8000/health`

## Production Notes

- Put the frontend and backend behind a real HTTPS reverse proxy before using camera/microphone features.
- Build the frontend with `API_BASE_URL` set to your public backend URL.
  Example: `docker build --build-arg API_BASE_URL=https://api.your-domain.com frontend/smart_healthcare`
- Keep `SUPABASE_SERVICE_ROLE_KEY` only on the backend. Never expose it to Flutter/web code.
- Use a strong `SECRET_KEY` and rotate it if it was shared.
- Replace the compose Postgres password before deploying outside local development.

## CI/CD

The GitHub Actions workflow at `.github/workflows/ci.yml` runs:

- Python dependency install and compile check.
- Backend Docker image build.
- Flutter dependency install, analyze, and web build.
- Docker Compose config validation.

For CD, add a deploy job after CI succeeds. Typical options:

- Push images to GitHub Container Registry.
- SSH into a VM and run `docker compose pull && docker compose up -d`.
- Deploy to Azure Container Apps using `.github/workflows/deploy-azure.yml`.
- Deploy to Railway using the Railway dashboard or `.github/workflows/deploy-railway.yml`.

See `AZURE_DEPLOYMENT.md` for the Azure Container Apps deployment path.
See `RAILWAY_DEPLOYMENT.md` for the Railway deployment path.
