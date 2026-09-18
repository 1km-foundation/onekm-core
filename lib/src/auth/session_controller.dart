import 'package:flutter/foundation.dart';

import 'session.dart';

/// Router-friendly session state: boot with [refresh], flip on login /
/// logout. `go_router` listens to this directly (`refreshListenable`).
class SessionController extends ChangeNotifier {
  SessionController(this.session);

  final Session session;

  bool _ready = false;
  bool _signedIn = false;

  bool get ready => _ready;
  bool get signedIn => _signedIn;

  /// First-run intro state. The router reads this live on every
  /// redirect (it refresh-listens on this controller), so completing
  /// onboarding routes forward instead of bouncing back.
  bool _onboardingSeen = true;
  bool get onboardingSeen => _onboardingSeen;

  /// Seed from local prefs at boot (before any redirect runs).
  void initOnboardingSeen(bool seen) {
    _onboardingSeen = seen;
  }

  /// Persist + flip when the user finishes onboarding; notifies so the
  /// pending redirect re-evaluates immediately.
  void markOnboardingSeen() {
    _onboardingSeen = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _signedIn = await session.signedIn;
    } catch (_) {
      // Secure storage can throw on first run / broken keystore —
      // boot unsigned rather than hanging on splash.
      _signedIn = false;
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> adoptedSignIn() async {
    _signedIn = true;
    _ready = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    await session.signOut();
    _signedIn = false;
    notifyListeners();
  }
}
