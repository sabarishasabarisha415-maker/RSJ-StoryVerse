import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

String firebaseErrorMessage(Object error, {required String operation}) {
  if (kDebugMode) {
    debugPrint('$operation failed: $error');
  }

  if (error is! FirebaseException) {
    return '$operation. Please try again.';
  }

  switch (error.code) {
    case 'permission-denied':
    case 'unauthorized':
      return "You don't have permission to access this data.";
    case 'unauthenticated':
      return 'Please sign in to continue.';
    case 'network-request-failed':
    case 'deadline-exceeded':
      return 'A network error occurred. Check your connection and try again.';
    case 'unavailable':
      return 'The database is temporarily unavailable. Please try again.';
    case 'bucket-not-found':
      return 'File storage has not been set up for this app yet.';
    case 'object-not-found':
      return 'This file is no longer available.';
    case 'no-app':
    case 'invalid-api-key':
    case 'app-not-authorized':
      return 'Firebase is not configured correctly for this app.';
    case 'failed-precondition':
      return 'This database request is not configured correctly. Please try again later.';
    case 'invalid-argument':
      return 'This database request is invalid. Please try again later.';
    default:
      return '$operation. Please try again.';
  }
}
