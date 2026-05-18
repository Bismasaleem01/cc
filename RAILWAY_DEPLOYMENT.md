# Railway Deployment

Railway is a good fit for this project because it can deploy each Docker service from this monorepo and provide PostgreSQL as a managed service.

## Services

Create two Railway services:

1. `smart-healthcare-db`
   - Add Railway PostgreSQL.

2. `smart-healthcare-backend`
   - Source: GitHub repo `Bismasaleem01/cc`
   - Root directory: `backend`
   - Dockerfile: `backend/Dockerfile`
   - Public networking: enabled
   - Health check path: `/health`

Deploy the frontend separately on Vercel. See `VERCEL_DEPLOYMENT.md`.

## Backend Variables

In the backend Railway service, set:

```text
DATABASE_URL=${{Postgres.DATABASE_URL}}
SECRET_KEY=generate-a-long-random-secret
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
GEMINI_API_KEY=your-gemini-key
SUPABASE_URL=your-supabase-project-url
SUPABASE_SERVICE_ROLE_KEY=your-supabase-service-role-key
SUPABASE_STORAGE_BUCKET=healthcare-files
```

Railway injects `PORT` automatically, so do not hardcode it.

## Frontend Variable on Vercel

After the backend service is deployed and Railway gives you a backend URL, set this variable on the Vercel frontend project:

```text
API_BASE_URL=https://your-backend-service.up.railway.app
```

Then redeploy the Vercel frontend.

## Important

- Camera and microphone require HTTPS. Railway public domains are HTTPS.
- Keep `SUPABASE_SERVICE_ROLE_KEY` only in the backend service.
- Do not commit `backend/.env`.
- If the backend Railway URL changes, update `API_BASE_URL` on the frontend and redeploy frontend.

## GitHub CI/CD Option

Railway can auto-deploy directly from GitHub when connected in the Railway dashboard.

If you prefer GitHub Actions deployment, add these GitHub secrets:

```text
RAILWAY_TOKEN
RAILWAY_BACKEND_SERVICE
```

Then run the `Deploy to Railway` workflow manually from GitHub Actions for backend deployment.
