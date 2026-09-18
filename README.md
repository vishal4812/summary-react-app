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
- Real Gemini transcription through the Python backend, followed by automatic summary generation
- Transcription errors shown without consuming summary usage
- Copy and share actions from the latest result
- Backend connection test in Settings
- Local identity reset in Settings for development

## What is still placeholder or dummy

- `/summarize` uses a local heuristic summarizer until a production provider is connected
- `/transcribe` requires `GEMINI_API_KEY` on the Python backend
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
cd /home/addweb/Learning/Pro/04-prototypes-needing-work/summary-app/summary-python-backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 127.0.0.1 --port 8010
```

Then start the Flutter web app:

```bash
cd /home/addweb/Learning/Pro/04-prototypes-needing-work/summary-app/summary-react-app
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 3000 \
  --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8010
```

Configure the backend's ignored `.env` using its `.env.example` before importing
audio. Keep Gemini credentials on the backend. Supported audio imports are AAC,
M4A, MP3, WAV, OGG, WebM, and FLAC, up to 20 MiB. The app accepts only completed
transcripts and automatically generates a summary, saves history, and updates
usage after a successful summary. A failed summary leaves the transcript available
for retry. Free-tier Gemini quotas and data handling apply.

For Android release builds, see `PLAY_STORE_READINESS.md`.

Open:

- frontend: `http://127.0.0.1:3000`
- backend health: `http://127.0.0.1:8010/health`

## Next implementation steps

1. Replace heuristic `/summarize` with a production summarization provider
2. Evaluate Hindi, Gujarati, and mixed-language recordings with Gemini
3. Add real audio recording from the app
4. Replace Pro preview with a real purchase flow
