# Summary App MVP

Flutter client for the Summary App MVP.

## Current product snapshot

The app is built around a simple MVP flow:

- WhatsApp-style voice note summary experience
- Hindi, Gujarati, and English selection in the UI
- Free limit with a temporary Pro preview switch
- Transcript-first summarization flow
- Local history, copy, and share support

## What is implemented now

- Product-shaped Flutter UI for studio, history, and settings
- Shared preferences persistence for settings and history
- Stable local device identity for usage tracking
- Real backend integration for:
  - `POST /usage/check`
  - `POST /usage/increment`
  - `POST /usage/reset`
  - `POST /summarize`
  - `POST /transcribe`
- Real audio file picking in the app
- Audio upload to the backend using multipart form data
- Imported audio transcript written back into the transcript box
- Copy and share actions from the latest result
- Backend connection test in Settings
- Local identity reset in Settings for development

## What is still placeholder or dummy

- `/summarize` still returns a fixed dummy summary payload
- `/transcribe` returns a placeholder transcript after a real upload
- Audio recording is still not implemented
- Payments are still represented by a Pro preview toggle

## Important behavior notes

- Usage is currently tracked per local device/browser, not by user account
- The app default backend URL in code is `http://127.0.0.1:8000`
- On this machine, port `8000` is occupied by another project, so local testing uses `http://127.0.0.1:8010`
- The app contains a local fallback from `127.0.0.1:8000` to `127.0.0.1:8010` when the default local port is unavailable

## Run locally

Start the backend first:

```bash
cd /home/addweb/Learning/Pro/summary-app/summary-python-backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 127.0.0.1 --port 8010
```

Then start the Flutter web app:

```bash
cd /home/addweb/Learning/Pro/summary-app/summary-react-app
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 3000
```

Open:

- frontend: `http://127.0.0.1:3000`
- backend health: `http://127.0.0.1:8010/health`

## Next implementation steps

1. Replace dummy `/summarize` with a real summarization provider
2. Replace placeholder `/transcribe` with real speech-to-text
3. Auto-trigger summary generation after successful transcription
4. Add real audio recording from the app
5. Replace Pro preview with a real purchase flow
