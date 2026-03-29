# Summary App MVP

This workspace now uses the shared ChatGPT discussion as the product brief.

## Product position

This is not a generic AI summarizer. The MVP is:

- WhatsApp-style voice note to summary
- Hindi and Gujarati first
- Fast, simple, low-friction flow
- Free tier with tight limits
- Pro tier for longer audio and deeper summaries

## MVP decisions pulled from the shared chat

- Free audio limit: 2 minutes
- Pro audio limit: 10 minutes
- Default output: 1 short summary + 3 bullet points
- Core screens:
  - Home
  - Processing
  - Result
  - History
  - Paywall
- Core actions:
  - Record audio
  - Import audio
  - Paste transcript
  - Copy summary
  - Share to WhatsApp

## What is implemented now

- Flutter app scaffold
- Product-shaped UI for the MVP
- Demo transcript generation for Hindi, Gujarati, and English
- Local history persistence with shared preferences
- Real clipboard copy and share actions
- Backend-ready summary service with mock fallback
- Settings screen for mock mode, backend URL, and Pro preview
- FastAPI backend folder with local quick-start endpoints
- Real usage and upload endpoints
- Dummy-only summarize endpoint for end-to-end app wiring

## Next implementation steps

1. Add real audio recording and file import
2. Implement `/summarize` on the backend and switch mock mode off
3. Add `/transcribe` so audio can become transcript
4. Replace Pro preview with real in-app purchase flow
5. Upgrade local persistence if history grows beyond simple cached JSON

## Suggested backend endpoints from the discussion

- `POST /transcribe`
- `POST /summarize`
- `POST /usage/check`
- `POST /usage/increment`

## Local backend quick start

```bash
cd /home/addweb/Learning/Pro/summary-app/summary-python-backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```
