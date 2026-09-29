# Firebase Hosting deployment

This guide prepares the Peladinhas Flutter Web app for a first public test on
Firebase Hosting. The repository stores hosting configuration, but it must not
store Supabase keys, passwords, tokens, or local environment files.

## Runtime values

The app reads these values at Flutter build time with `--dart-define`:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `BACKEND_API_BASE_URL`

For the public test backend, use:

```text
BACKEND_API_BASE_URL=https://peladinhas-backend.onrender.com
```

Use the Supabase publishable/anon key from the Supabase project dashboard only
when running the build command. Do not paste it into tracked source files.

## One-time Firebase setup

Install and sign in to the Firebase command-line interface:

```powershell
npm install -g firebase-tools
firebase login
```

Create or select a Firebase project in the Firebase console, then connect this
local checkout to that project without committing the generated `.firebaserc`
unless the project identifier is intentionally public:

```powershell
firebase projects:list
firebase use --add
```

When prompted, choose the Firebase project and assign an alias such as
`production`.

## Production web build

From the repository root, provide the Supabase values only in the current
PowerShell session:

```powershell
$env:SUPABASE_URL="https://YOUR-SUPABASE-PROJECT.supabase.co"
$env:SUPABASE_ANON_KEY="YOUR-SUPABASE-PUBLISHABLE-OR-ANON-KEY"

flutter pub get
flutter analyze
flutter test
flutter build web --release `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY `
  --dart-define=BACKEND_API_BASE_URL=https://peladinhas-backend.onrender.com
```

The generated deployment files are written to `build/web`, which is ignored by
Git.

## Deploy

Deploy only after the build succeeds:

```powershell
firebase deploy --only hosting
```

Firebase Hosting serves `build/web`. The `firebase.json` rewrite sends every
direct browser URL back to `/index.html`, so refreshing Flutter Web routes does
not produce a Firebase 404 page.

## Backend CORS

After Firebase prints the final Hosting URL, update Render so the backend
environment variable includes that origin:

```text
PELADINHAS_CORS_ALLOWED_ORIGINS=https://YOUR-FIREBASE-HOSTING-URL
```

If multiple origins are needed, keep the format expected by the backend
configuration and include the exact Firebase Hosting URL.
