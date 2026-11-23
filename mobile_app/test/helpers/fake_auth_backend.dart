import 'dart:async';

import 'package:nawadir_aliibil/features/auth/data/auth_backend.dart';

/// خلفية دخول للاختبارات: ترمي ما تُضبط عليه، وتغير الحالة عند نجاح التحقق.
class FakeAuthBackend implements AuthBackend {
  FakeAuthBackend({this.signedIn = false, this.validCode = '123456'});

  bool signedIn;

  @override
  String? phone = '966500000001';

  @override
  String? get userId => signedIn ? 'user-me' : null;
  final String validCode;

  AuthFailure? sendFailure;
  AuthFailure? verifyFailure;

  final sentTo = <String>[];
  final verified = <(String, String)>[];
  var signOutCalls = 0;

  final _changes = StreamController<bool>.broadcast(sync: true);

  @override
  bool get isSignedIn => signedIn;

  @override
  Stream<bool> get signedInChanges => _changes.stream;

  @override
  Future<void> sendOtp(String phoneE164) async {
    sentTo.add(phoneE164);
    if (sendFailure != null) throw sendFailure!;
  }

  @override
  Future<void> verifyOtp(String phoneE164, String code) async {
    verified.add((phoneE164, code));
    if (verifyFailure != null) throw verifyFailure!;
    if (code != validCode) {
      throw const AuthFailure(AuthFailureKind.invalidCode);
    }
    signedIn = true;
    _changes.add(true);
  }

  final passwordLogins = <(String, String)>[];

  @override
  Future<void> signInWithPassword(String email, String password) async {
    passwordLogins.add((email, password));
    if (verifyFailure != null) throw verifyFailure!;
    if (password != 'dev-pass') {
      throw const AuthFailure(AuthFailureKind.invalidCode);
    }
    signedIn = true;
    _changes.add(true);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    signedIn = false;
    _changes.add(false);
  }
}
