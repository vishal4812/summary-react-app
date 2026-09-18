# Privacy Policy Draft

Effective date: Replace before publishing

Voice Note Summary helps users turn pasted transcripts and imported audio files into summaries.

## Information Processed

The app may process:

- Text entered or pasted by the user
- Audio files selected by the user
- Generated summaries
- A locally generated device identifier used to track free usage limits
- Local history and settings stored on the user's device

## How Information Is Used

User-provided text and audio are sent to the configured backend only to generate transcripts, summaries, and usage-limit responses. Local history and settings are stored on the user's device to keep the app experience consistent between sessions.

## Data Sharing

The current backend sends imported audio and selected language hints to Google's
Gemini API for speech-to-text. It disables interaction storage for transcription
requests. Google's own retention and data handling policies still apply, and
free-tier content may be used to improve Google's products. See
[Gemini terms](https://ai.google.dev/gemini-api/terms).

Text summaries currently use a local algorithm on the backend. Before publishing
this policy, confirm the deployed backend and API tier, and document any additional
providers or changes to data handling.

## Data Retention

The current backend processes new audio uploads without saving them to its runtime
upload directory. Files retained by older prototype versions are not automatically
deleted. Before production, define and implement a deletion policy for legacy
uploads and usage records, and confirm Google's retention behavior for the chosen
API tier. History and settings remain on the user's device.

## User Controls

The app includes controls to clear local history and reset the local app identity. Production releases should also document how users can request deletion of backend-stored data.

## Contact

Replace with the developer or company contact email before publishing.
