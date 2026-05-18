# Vercel Frontend Deployment

Use Vercel for the Flutter web frontend and Railway for the backend/Postgres.

## 1. Import Project

1. Open Vercel.
2. Click `Add New -> Project`.
3. Import GitHub repo `Bismasaleem01/cc`.
4. Set the project root directory to:

   ```text
   frontend/smart_healthcare
   ```

Vercel will read `frontend/smart_healthcare/vercel.json`.

## 2. Environment Variable

After the Railway backend is deployed, copy the backend public URL and set this Vercel environment variable:

```text
API_BASE_URL=https://your-backend-service.up.railway.app
```

Do not use the frontend URL here. This must be the Railway backend URL.

## 3. Build Settings

The project includes these Vercel settings in `vercel.json`:

```text
Build Command: bash scripts/vercel_build.sh
Output Directory: build/web
Install Command: true
```

The build script installs Flutter if needed, runs `flutter pub get`, and builds Flutter web with:

```text
--dart-define=API_BASE_URL=$API_BASE_URL
```

## 4. Access

After deployment, patients and doctors open the Vercel frontend URL:

```text
https://your-vercel-project.vercel.app
```

The frontend will call the Railway backend URL configured in `API_BASE_URL`.

## 5. Notes

- Camera and microphone require HTTPS. Vercel provides HTTPS.
- If the Railway backend URL changes, update `API_BASE_URL` in Vercel and redeploy.
- Keep backend secrets only in Railway, not Vercel.
