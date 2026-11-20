import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_handler.dart';
import '../data/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _aboutController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider).valueOrNull;
    _nameController = TextEditingController(text: profile?.displayName ?? '');
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _aboutController = TextEditingController(text: profile?.about ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            userId: profile.id,
            displayName: _nameController.text.trim(),
            username: _usernameController.text.trim().isEmpty
                ? null
                : _usernameController.text.trim(),
            about: _aboutController.text.trim(),
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isLoading ? null : _handleSave,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Display name cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username (optional)',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _aboutController,
                decoration: const InputDecoration(
                  labelText: 'About / Bio',
                  prefixIcon: Icon(Icons.info_outline),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
