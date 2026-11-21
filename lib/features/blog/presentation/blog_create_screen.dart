import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/error_handler.dart';
import '../../rbac/data/rbac_repository.dart';
import '../data/blog_repository.dart';
import '../data/blog_storage_service.dart';
import '../models/blog_post.dart';

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
  String _selectedCategory = BlogCategories.news;
  bool _publishNow = true;
  bool _isLoading = false;
  bool _isUploadingMedia = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _mediaUrlController.dispose();
    super.dispose();
  }

  Future<void> _handlePickImage(ImageSource source) async {
    final uid = ref.read(blogRepositoryProvider).currentUserId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to upload media.')),
      );
      return;
    }

    setState(() => _isUploadingMedia = true);
    try {
      final url = await ref
          .read(blogStorageServiceProvider)
          .pickAndUploadCoverImage(authorId: uid, source: source);
      if (url != null && mounted) {
        setState(() {
          _mediaUrlController.text = url;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) ErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(blogRepositoryProvider).createPost(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            type: _selectedType,
            category: _selectedCategory,
            coverUrl: _mediaUrlController.text.trim().isNotEmpty
                ? _mediaUrlController.text.trim()
                : null,
            publishNow: _publishNow,
          );

      ref.invalidate(blogFeedProvider);
      ref.invalidate(myDraftsProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _publishNow ? 'Post published successfully!' : 'Draft saved to My Drafts.',
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
    final theme = Theme.of(context);
    final canPublish = ref.can('blog.publish');

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
            tooltip: 'Save Post',
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
              // Row: Post Type & Category
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'text',
                          child: Text('Text + Cover'),
                        ),
                        DropdownMenuItem(
                          value: 'image',
                          child: Text('Image Gallery'),
                        ),
                        DropdownMenuItem(
                          value: 'audio',
                          child: Text('Audio / Podcast'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: BlogCategories.all.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(
                            BlogCategories.getDisplayName(cat),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter a descriptive title...',
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

              // Media Upload & URL Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mediaUrlController,
                      decoration: InputDecoration(
                        labelText: _selectedType == 'audio'
                            ? 'Audio URL (mp3/m4a)'
                            : 'Cover Image URL',
                        hintText: 'https://...',
                        prefixIcon: Icon(
                          _selectedType == 'audio'
                              ? Icons.audiotrack
                              : Icons.image,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_selectedType != 'audio') ...[
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: _isUploadingMedia
                          ? null
                          : () => _handlePickImage(ImageSource.gallery),
                      icon: _isUploadingMedia
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_upload_outlined),
                      label: const Text('Upload'),
                    ),
                  ],
                ],
              ),

              // Image Preview
              if (_mediaUrlController.text.trim().isNotEmpty &&
                  _selectedType != 'audio') ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: _mediaUrlController.text.trim(),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 160,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 80,
                      color: theme.colorScheme.errorContainer.withAlpha(50),
                      padding: const EdgeInsets.all(8),
                      child: const Row(
                        children: [
                          Icon(Icons.broken_image, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Invalid image preview URL'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Body Content Field
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Body / Article Content',
                  hintText: 'Write educational content, news, or insights...',
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
              ),
              const SizedBox(height: 16),

              // Publish Switch (Guarded by blog.publish permission if non-admin)
              SwitchListTile(
                title: const Text('Publish Immediately'),
                subtitle: Text(
                  !canPublish
                      ? 'You lack publishing permissions. Saved as draft for admin review.'
                      : (_publishNow
                          ? 'Visible immediately to all readers'
                          : 'Save as draft (only visible to you)'),
                ),
                value: canPublish && _publishNow,
                onChanged: !canPublish
                    ? null
                    : (val) => setState(() => _publishNow = val),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
