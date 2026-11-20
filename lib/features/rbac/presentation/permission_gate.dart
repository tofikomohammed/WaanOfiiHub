import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rbac_repository.dart';

/// Conditionally renders [child] if the current user possesses [permission].
/// Otherwise renders [fallback] (defaults to SizedBox.shrink()).
class PermissionGate extends ConsumerWidget {
  final String permission;
  final Widget child;
  final Widget fallback;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPerm = ref.can(permission);
    if (hasPerm) {
      return child;
    }
    return fallback;
  }
}
