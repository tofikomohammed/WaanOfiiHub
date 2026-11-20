import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

class AuthNotifier extends ChangeNotifier {
  final AuthRepository _repo;
  StreamSubscription<AuthState>? _sub;

  AuthNotifier(this._repo) {
    _sub = _repo.authStateChanges?.listen((_) {
      notifyListeners();
    });
  }

  bool get isAuthenticated => _repo.currentUser != null;
  User? get currentUser => _repo.currentUser;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final authNotifierProvider = Provider<AuthNotifier>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final notifier = AuthNotifier(repo);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

final authStateProvider = StreamProvider<AuthState?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges ?? const Stream.empty();
});

final currentAuthUserProvider = Provider<User?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.currentUser;
});
