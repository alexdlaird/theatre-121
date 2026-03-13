import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('google_auth_service');

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();

  factory GoogleAuthService() => _instance;

  GoogleAuthService._internal();

  static const driveFileScope = 'https://www.googleapis.com/auth/drive.file';

  final googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      driveFileScope,
    ],
  );

  AuthClient? _cachedClient;

  /// Whether an auth client is currently cached and available.
  bool get hasAuthClient => _cachedClient != null;

  /// Initializes and caches the auth client after login.
  /// Call this after successful Google sign-in to pre-authorize
  /// all required scopes and cache the client for the session.
  Future<void> initAuthClient() async {
    final account = googleSignIn.currentUser;
    if (account == null) {
      throw StateError('No signed-in user. Call this after successful sign-in.');
    }

    // Request the drive.file scope explicitly - this triggers OAuth consent on web
    // and ensures we get an access token (not just an ID token from FedCM)
    final hasScope = await googleSignIn.requestScopes([driveFileScope]);
    if (!hasScope) {
      throw StateError('Google Sheets access denied. Please grant permission to continue.');
    }

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

    _cachedClient = authenticatedClient(http.Client(), credentials);
    _log.info('Auth client initialized and cached');
  }

  /// Returns the cached auth client, or re-authenticates if needed.
  /// Prefer calling [initAuthClient] at login to avoid mid-session prompts.
  Future<AuthClient> getAuthClient() async {
    // Return cached client if available
    if (_cachedClient != null) {
      return _cachedClient!;
    }

    _log.info('No cached auth client, re-authenticating...');

    var account = googleSignIn.currentUser;
    account ??= await googleSignIn.signInSilently();

    // If no account, sign in
    if (account == null) {
      account = await googleSignIn.signIn();
      if (account == null) {
        throw StateError('Google sign-in required. Please try again.');
      }
    }

    // Request the drive.file scope explicitly
    final hasScope = await googleSignIn.requestScopes([driveFileScope]);
    if (!hasScope) {
      throw StateError('Google Sheets access denied. Please grant permission to continue.');
    }

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

    _cachedClient = authenticatedClient(http.Client(), credentials);
    _log.info('Auth client re-authenticated and cached');
    return _cachedClient!;
  }

  /// Clears the cached auth client, forcing re-authentication on next request.
  void clearCache() {
    _cachedClient?.close();
    _cachedClient = null;
  }
}
