# Private Password Manager

A private, cross-platform Flutter password manager for Android, Linux, and Windows.

## Security Model

- Firebase Authentication stores the cloud identity.
- Cloud Firestore stores only encrypted vault content.
- Folder names and password entry fields are encrypted locally with AES-GCM.
- The vault key is derived locally from a master password with Argon2id.
- The master password is never sent to Firebase and is not stored locally.

Losing the master password means the encrypted vault cannot be recovered.

## Firebase Setup

1. Create a Firebase project on the Spark/free plan.
2. Enable Email/Password authentication.
3. Create a Cloud Firestore database.
4. Deploy `firestore.rules`.
5. Copy `.env.sample` to `.env` and fill in your Firebase project ID and web API key.

## Free-Tier Notes

The app uses Firebase Auth and Firestore only. It avoids Cloud Functions, Storage, paid APIs, and broad listeners. Folders are listened to once, and password entries are streamed only for the currently selected folder.

## Run

```bash
flutter pub get
flutter run -d linux
flutter run -d windows
flutter run -d android
```

## Build

```bash
flutter build apk --release
flutter build linux --release
flutter build windows --release
```
