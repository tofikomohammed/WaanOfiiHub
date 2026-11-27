import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../rbac/data/rbac_repository.dart';
import '../data/blog_repository.dart';
import '../data/blog_storage_service.dart';
import '../models/blog_post.dart';
import 'blog_detail_screen.dart';
import 'widgets/audio_player_widget.dart';

class BlogEditScreen extends ConsumerStatefulWidget {
  final String postId;

  const BlogEditScreen({super.key, required this.postId});

  @override
  ConsumerState<BlogEditScreen> createState() => _BlogEditScreenState();
}

class _BlogEditScreenState extends ConsumerState<BlogEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _mediaUrlController;
  late final TextEditingController _tagsController;

  String _selectedType = 'text';
  String _selectedCategory = BlogCategories.news;
  String _selectedStatus = 'draft';
  DateTime? _scheduledFor;
  bool _isPinned = false;
  bool _isLoading = false;
  bool _isUploadingMedia = false;
  bool _isInitialized = false;

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledFor ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledFor ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (combined.isBefore(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scheduled time must be in the future.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _scheduledFor = combined;
      _selectedStatus = 'scheduled';
    });
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _mediaUrlController = TextEditingController();
    _tagsController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _mediaUrlController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _populateFields(BlogPost post) {
    if (_isInitialized) return;
    _titleController.text = post.title;
    _bodyController.text = post.body;
    _mediaUrlController.text = post.coverUrl ?? '';
    _tagsController.text = post.tags.join(', ');
    _selectedType = post.type;
    _selectedCategory = post.category;
    _selectedStatus = post.status;
    _scheduledFor = post.scheduledFor;
    _isPinned = post.isPinned;
    _isInitialized = true;
  }

  Future<void> _handlePickImage(ImageSource source) async {
    final uid = ref.read(blogRepositoryProvider).currentUserId;
    if (uid == null) return;

    setState(() => _isUploadingMedia = true);
    try {
      final item = await ref
          .read(blogStorageServiceProvider)
          .pickAndUploadCoverImage(authorId: uid, source: source);
      if (item != null && mounted) {
        setState(() {
          _mediaUrlController.text = item.publicUrl;
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

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final tags = _tagsController.text
          .split(RegExp(r'[, ]+'))
          .map((t) => t.replaceAll('#', '').trim())
          .where((t) => t.isNotEmpty)
          .toList();

      await ref
          .read(blogRepositoryProvider)
          .updatePost(
            id: widget.postId,
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            type: _selectedType,
            category: _selectedCategory,
            tags: tags,
            coverUrl: _mediaUrlController.text.trim().isNotEmpty
                ? _mediaUrlController.text.trim()
                : null,
            status: _selectedStatus,
            scheduledFor: _selectedStatus == 'scheduled' ? _scheduledFor : null,
            isPinned: _isPinned,
          );

      ref.invalidate(blogFeedProvider);
      ref.invalidate(myDraftsProvider);
      ref.invalidate(postDetailProvider(widget.postId));

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully!')),
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
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final canPublish = ref.can('blog.publish');
    final canPin = ref.can('blog.edit_any');

    return postAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Edit Post')),
        body: const LoadingIndicator(message: 'Loading post...'),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('Edit Post')),
        body: ErrorView(
          message: 'Unable to load post details',
          onRetry: () => ref.invalidate(postDetailProvider(widget.postId)),
        ),
      ),
      data: (post) {
        if (post == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Post')),
            body: const Center(child: Text('Post not found')),
          );
        }

        _populateFields(post);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Blog Post'),
            actions: [
              IconButton(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                tooltip: 'Save Changes',
                onPressed: _isLoading ? null : _handleUpdate,
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
                            if (val != null) {
                              setState(() => _selectedType = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
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
                            if (val != null) {
                              setState(() => _selectedCategory = val);
                            }
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

                  // Media URL & Upload
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                      ),
                    ),
                  ],

                  // Audio Preview
                  if (_mediaUrlController.text.trim().isNotEmpty &&
                      _selectedType == 'audio') ...[
                    const SizedBox(height: 12),
                    AudioPlayerWidget(
                      audioUrl: _mediaUrlController.text.trim(),
                      title: _titleController.text.isEmpty
                          ? 'Audio Preview'
                          : _titleController.text,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Tags Field
                  TextFormField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags (e.g. innovation, health, tips)',
                      prefixIcon: Icon(Icons.tag),
                      hintText: 'Comma-separated tags',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Body Content Field
                  TextFormField(
                    controller: _bodyController,
                    decoration: const InputDecoration(
                      labelText: 'Body / Article Content',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 8,
                  ),
                  const SizedBox(height: 16),

                  // Status Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      const DropdownMenuItem(
                        value: 'draft',
                        child: Text('Draft (Unpublished)'),
                      ),
                      if (canPublish) ...[
                        const DropdownMenuItem(
                          value: 'published',
                          child: Text('Published'),
                        ),
                        const DropdownMenuItem(
                          value: 'scheduled',
                          child: Text('Scheduled Publication'),
                        ),
                      ],
                      const DropdownMenuItem(
                        value: 'archived',
                        child: Text('Archived'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedStatus = val);
                        if (val == 'scheduled' && _scheduledFor == null) {
                          _pickScheduleDateTime();
                        }
                      }
                    },
                  ),
                  if (_selectedStatus == 'scheduled') ...[
                    const SizedBox(height: 12),
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(
                          Icons.schedule_rounded,
                          color: Colors.purple,
                        ),
                        title: Text(
                          _scheduledFor != null
                              ? 'Scheduled: ${DateFormat.yMMMd().add_jm().format(_scheduledFor!.toLocal())}'
                              : 'Set Schedule Time',
                        ),
                        subtitle: const Text(
                          'Tap to change publication date & time',
                        ),
                        trailing: const Icon(Icons.edit_calendar, size: 20),
                        onTap: _pickScheduleDateTime,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Pin Post Toggle (Admins)
                  if (canPin)
                    SwitchListTile(
                      title: const Text('Pin to Top of Feed'),
                      subtitle: const Text('Featured priority announcement'),
                      value: _isPinned,
                      onChanged: (val) => setState(() => _isPinned = val),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
