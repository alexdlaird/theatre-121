import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();

  factory GoogleAuthService() => _instance;

  GoogleAuthService._internal();

  static const driveFileScope = 'https://www.googleapis.com/auth/drive.file';
  static const _cacheDuration = Duration(seconds: 30);

  final googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      driveFileScope,
    ],
  );

  AuthClient? _cachedClient;
  DateTime? _cachedAt;

  /// Returns an authenticated HTTP client for Google APIs.
  /// Caches the client for 30 seconds to avoid repeated OAuth prompts
  /// during back-to-back operations.
  Future<AuthClient> getAuthClient() async {
    // Return cached client if still valid
    if (_cachedClient != null && _cachedAt != null) {
      if (DateTime.now().difference(_cachedAt!) < _cacheDuration) {
        return _cachedClient!;
      }
      // Cache expired, close the old client
      _cachedClient!.close();
      _cachedClient = null;
      _cachedAt = null;
    }

    var account = googleSignIn.currentUser;
    account ??= await googleSignIn.signInSilently();

    // If no account, sign in
    if (account == null) {
      account = await googleSignIn.signIn();
      if (account == null) {
        throw StateError('Google sign-in required. Please try again.');
      }
    }

    // Request the drive.file scope explicitly - this triggers OAuth consent on web
    // and ensures we get an access token (not just an ID token from FedCM)
    final hasScope = await googleSignIn.requestScopes([driveFileScope]);
    if (!hasScope) {
      throw StateError('Google Sheets access denied. Please grant permission to continue.');
    }

    // Now get the authentication with the proper access token
    final auth = await account.authentication;

    if (auth.accessToken == null) {
      throw StateError('Unable to get Google access token. Please sign out and sign back in.');
    }

    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        auth.accessToken!,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      [driveFileScope],
    );

    final client = authenticatedClient(http.Client(), credentials);
    _cachedClient = client;
    _cachedAt = DateTime.now();
    return client;
  }

  /// Clears the cached auth client, forcing re-authentication on next request.
  void clearCache() {
    _cachedClient?.close();
    _cachedClient = null;
    _cachedAt = null;
  }
}
