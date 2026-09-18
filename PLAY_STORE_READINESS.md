# Play Store Readiness

This app is configured for Android package `com.addweb.voicenotesummary` and display name `Voice Note Summary`.

## Before Building a Play Release

1. Install a full JDK, not only a JRE. The current machine has Java 21 runtime but no `javac`, so Gradle release builds fail until the JDK is fixed.

```bash
sudo apt-get update
sudo apt-get install openjdk-21-jdk
```
2. Create an Android upload keystore:

```bash
cd /home/addweb/Learning/Pro/04-prototypes-needing-work/summary-app/summary-react-app/android
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

3. Copy `android/key.properties.example` to `android/key.properties` and fill in the real passwords.
4. Deploy the backend to HTTPS and pass its public URL at build time:

```bash
flutter build appbundle --release \
  --dart-define=BACKEND_BASE_URL=https://your-api-domain.example
```

The generated bundle should be at `build/app/outputs/bundle/release/app-release.aab`.

## Remaining Product Gaps

- `/transcribe` still returns a placeholder transcript. Do not claim real voice-note transcription in the Play listing until speech-to-text is connected.
- Replace the default Flutter launcher icon with a final branded icon before production.
- Host the privacy policy at a public URL and use that URL in Play Console.
- Complete Play Console Data Safety based on the deployed backend's real data handling.
- If your Play developer account is a personal account created after November 13, 2023, run the required closed test with at least 12 opted-in testers for 14 continuous days before applying for production.
