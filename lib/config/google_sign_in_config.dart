import 'package:google_sign_in/google_sign_in.dart';

/// Shared GoogleSignIn instance for the app.
/// This ensures the same auth state is used for both Firebase Auth and Google APIs.
final googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'https://www.googleapis.com/auth/drive.file',
  ],
);
