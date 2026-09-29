import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/firebase_error.dart';

void main() {
  test('permission errors do not expose Firebase diagnostics', () {
    final message = firebaseErrorMessage(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'private backend details',
      ),
      operation: 'Loading stories',
    );

    expect(message, "You don't have permission to access this data.");
    expect(message, isNot(contains('private backend details')));
  });

  test('authentication errors request sign-in', () {
    final message = firebaseErrorMessage(
      FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated'),
      operation: 'Loading stories',
    );

    expect(message, 'Please sign in to continue.');
  });

  test('Firestore availability errors are distinct from network failures', () {
    final unavailableMessage = firebaseErrorMessage(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      operation: 'Loading stories',
    );
    final networkMessage = firebaseErrorMessage(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'network-request-failed',
      ),
      operation: 'Loading stories',
    );

    expect(unavailableMessage, contains('database is temporarily unavailable'));
    expect(networkMessage, contains('network error'));
  });
}
