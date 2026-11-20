import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_handler.dart';
import '../../rbac/data/rbac_repository.dart';
import '../data/chat_repository.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _titleController = TextEditingController();
  bool _isCommunity = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .createGroup(title: title, memberIds: [], isCommunity: _isCommunity);
      ref.invalidate(conversationsListProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isCommunity
                  ? 'Community channel created!'
                  : 'Group created successfully!',
            ),
          ),
        );
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
    final canManageCommunity = ref.can('community.manage');

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Group / Channel'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isLoading ? null : _handleCreate,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Group or Channel Name',
                prefixIcon: Icon(Icons.group_outlined),
              ),
            ),
            if (canManageCommunity) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Community Channel'),
                subtitle: const Text(
                  'Make this a public open community channel for all members',
                ),
                value: _isCommunity,
                onChanged: (val) => setState(() => _isCommunity = val),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
