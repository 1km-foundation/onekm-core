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
