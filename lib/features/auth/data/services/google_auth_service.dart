import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/youtube/v3.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      YouTubeApi.youtubeScope,
    ],
  );

  GoogleSignIn get googleSignIn => _googleSignIn;
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  Stream<GoogleSignInAccount?> get onCurrentUserChanged => _googleSignIn.onCurrentUserChanged;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (e) {
      print('🔴 [GoogleAuthService] Sign-in failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('🔴 [GoogleAuthService] Sign-out failed: $e');
      rethrow;
    }
  }

  Future<bool> isSignedIn() async {
    return _googleSignIn.isSignedIn();
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      print('🔴 [GoogleAuthService] Silent sign-in failed: $e');
      return null;
    }
  }
}
