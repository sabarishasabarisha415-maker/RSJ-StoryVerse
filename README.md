# RSJ StoryVerse

RSJ StoryVerse is a Flutter application using Firebase Authentication,
Cloud Firestore, and Firebase Storage. Firebase is initialized from
`lib/firebase_options.dart`; this project does not use a separate API server or
environment-variable file.

## Run the application

From the project directory in PowerShell:

```powershell
flutter pub get
flutter run -d chrome
```

Use `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 57186` to
run the Flutter web server on a fixed local port.

## Firebase setup

The configured Firebase project is `rsj-storyverse`. Enable Email/Password in
Firebase Authentication. StoryVerse requires an email/password account before
any story, library, or profile data is available. Anonymous accounts are not
accepted for application data access.

Firestore rules are in `firestore.rules` and are mapped in `firebase.json`.
They require Firebase email/password authentication to read or write stories.
Any email-authenticated user can read stories and create stories; only the UID
recorded as the author can update or delete a story. Likes and comments are
available to authenticated readers; each user can remove only their own like,
and comment authors alone can edit or delete their comments. Profiles, reading
history, and favorites remain private to their owner. Deploy the rules with:

```powershell
firebase deploy --only firestore:rules --project rsj-storyverse
```

Firebase Storage must first be initialized in the Firebase Console for
`rsj-storyverse` (choose the bucket location and any required billing plan).
After the bucket has been created, deploy the owner-scoped Storage rules with:

```powershell
firebase deploy --only storage --project rsj-storyverse
```

The checked-in Storage rules limit image uploads to JPEG, PNG, and WebP files
of at most 10 MB and require email/password authentication. Profile images
remain owner-restricted; story covers are available only to authenticated
email/password users through Storage rules. Legacy root-level cover files
remain read-only for compatibility.

## Checks

```powershell
flutter analyze
flutter test
flutter build web
firebase emulators:exec --only auth,firestore --project demo-rsj-storyverse "node test\firestore_rules_emulator_test.js"
```
