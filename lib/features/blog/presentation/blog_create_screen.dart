import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_handler.dart';
import '../data/blog_repository.dart';

class BlogCreateScreen extends ConsumerStatefulWidget {
  const BlogCreateScreen({super.key});

  @override
  ConsumerState<BlogCreateScreen> createState() => _BlogCreateScreenState();
}

class _BlogCreateScreenState extends ConsumerState<BlogCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _mediaUrlController = TextEditingController();
  String _selectedType = 'text';
  bool _publishNow = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _mediaUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(blogRepositoryProvider)
          .createPost(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            type: _selectedType,
            coverUrl: _mediaUrlController.text.trim().isNotEmpty
                ? _mediaUrlController.text.trim()
                : null,
            publishNow: _publishNow,
          );
      ref.invalidate(blogFeedProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _publishNow ? 'Post published successfully!' : 'Draft saved.',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Blog Post'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Post Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'text',
                    child: Text('Text + Cover Image'),
                  ),
                  DropdownMenuItem(
                    value: 'image',
                    child: Text('Image Gallery / Photo'),
                  ),
                  DropdownMenuItem(
                    value: 'audio',
                    child: Text('Audio / Podcast Post'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mediaUrlController,
                decoration: InputDecoration(
                  labelText: _selectedType == 'audio'
                      ? 'Audio URL (mp3/m4a)'
                      : 'Cover Image URL',
                  prefixIcon: Icon(
                    _selectedType == 'audio' ? Icons.audiotrack : Icons.image,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Body / Content',
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Publish Immediately'),
                subtitle: const Text('Turn off to save as draft'),
                value: _publishNow,
                onChanged: (val) => setState(() => _publishNow = val),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
