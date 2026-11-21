import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/error_handler.dart';
import '../../rbac/data/rbac_repository.dart';
import '../data/blog_repository.dart';
import '../data/blog_storage_service.dart';
import '../models/blog_post.dart';
import 'widgets/audio_player_widget.dart';

class BlogCreateScreen extends ConsumerStatefulWidget {
  const BlogCreateScreen({super.key});

  @override
  ConsumerState<BlogCreateScreen> createState() => _BlogCreateScreenState();
}

class _BlogCreateScreenState extends ConsumerState<BlogCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _coverUrlController = TextEditingController();
  final _tagsController = TextEditingController();

  String _selectedType = 'text';
  String _selectedCategory = BlogCategories.news;
  bool _publishNow = true;
  bool _isScheduled = false;
  DateTime? _scheduledDateTime;
  bool _isLoading = false;

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDateTime ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledDateTime ?? now.add(const Duration(hours: 1)),
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
          const SnackBar(content: Text('Scheduled time must be in the future.')),
        );
      }
      return;
    }

    setState(() {
      _scheduledDateTime = combined;
      _isScheduled = true;
      _publishNow = false;
    });
  }

  // Media state
  bool _isUploadingMedia = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  final List<UploadedMediaItem> _galleryItems = [];
  UploadedMediaItem? _audioItem;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _coverUrlController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _handlePickCoverImage(ImageSource source) async {
    final uid = ref.read(blogRepositoryProvider).currentUserId;
    if (uid == null) return;

    setState(() {
      _isUploadingMedia = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Selecting image...';
    });

    try {
      final item = await ref.read(blogStorageServiceProvider).pickAndUploadCoverImage(
            authorId: uid,
            source: source,
            onProgress: (prog, status) {
              if (mounted) {
                setState(() {
                  _uploadProgress = prog;
                  _uploadStatus = status;
                });
              }
            },
          );

      if (item != null && mounted) {
        setState(() {
          _coverUrlController.text = item.publicUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cover image uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) ErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _handlePickGalleryImages() async {
    final uid = ref.read(blogRepositoryProvider).currentUserId;
    if (uid == null) return;

    setState(() {
      _isUploadingMedia = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Selecting images...';
    });

    try {
      final items = await ref
          .read(blogStorageServiceProvider)
          .pickAndUploadGalleryImages(
            authorId: uid,
            onProgress: (prog, status) {
              if (mounted) {
                setState(() {
                  _uploadProgress = prog;
                  _uploadStatus = status;
                });
              }
            },
          );

      if (items.isNotEmpty && mounted) {
        setState(() {
          _galleryItems.addAll(items);
          if (_coverUrlController.text.trim().isEmpty) {
            _coverUrlController.text = items.first.publicUrl;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${items.length} images added to gallery.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) ErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _handlePickAudio() async {
    final uid = ref.read(blogRepositoryProvider).currentUserId;
    if (uid == null) return;

    // Use ImagePicker to pick audio file or video/audio
    final picker = ImagePicker();
    final xFile = await picker.pickMedia();
    if (xFile == null) return;

    setState(() {
      _isUploadingMedia = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Reading audio file...';
    });

    try {
      final bytes = await xFile.readAsBytes();
      final item = await ref.read(blogStorageServiceProvider).uploadAudio(
            authorId: uid,
            fileName: xFile.name,
            bytes: bytes,
            onProgress: (prog, status) {
              if (mounted) {
                setState(() {
                  _uploadProgress = prog;
                  _uploadStatus = status;
                });
              }
            },
          );

      if (mounted) {
        setState(() {
          _audioItem = item;
          _coverUrlController.text = item.publicUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio uploaded and ready for preview!')),
        );
      }
    } catch (e) {
      if (mounted) ErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  void _reorderGallery(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _galleryItems.removeAt(oldIndex);
      _galleryItems.insert(newIndex, item);
    });
  }

  void _removeGalleryItem(int index) {
    setState(() {
      final removed = _galleryItems.removeAt(index);
      if (_coverUrlController.text == removed.publicUrl) {
        _coverUrlController.text =
            _galleryItems.isNotEmpty ? _galleryItems.first.publicUrl : '';
      }
    });
  }

  void _setAsCover(int index) {
    setState(() {
      _coverUrlController.text = _galleryItems[index].publicUrl;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Set as post cover image!')),
    );
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final tags = _tagsController.text
          .split(RegExp(r'[, ]+'))
          .map((t) => t.replaceAll('#', '').trim())
          .where((t) => t.isNotEmpty)
          .toList();

      await ref.read(blogRepositoryProvider).createPost(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            type: _selectedType,
            category: _selectedCategory,
            coverUrl: _coverUrlController.text.trim().isNotEmpty
                ? _coverUrlController.text.trim()
                : null,
            publishNow: _publishNow,
            scheduledFor: _isScheduled ? _scheduledDateTime : null,
            tags: tags,
            galleryMedia: _selectedType == 'image'
                ? _galleryItems
                : (_selectedType == 'audio' && _audioItem != null
                    ? [_audioItem!]
                    : []),
          );

      ref.invalidate(blogFeedProvider);
      ref.invalidate(myDraftsProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isScheduled
                  ? 'Post scheduled for publication!'
                  : (_publishNow
                      ? 'Post published successfully!'
                      : 'Draft saved to My Drafts.'),
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
                          child: Text('Text Article'),
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
                  hintText: 'Enter title...',
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

              // Upload Progress Bar
              if (_isUploadingMedia) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _uploadStatus,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('${(_uploadProgress * 100).toInt()}%'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _uploadProgress),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // AUDIO SECTION
              if (_selectedType == 'audio') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _coverUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Audio URL (MP3, M4A, WAV)',
                          prefixIcon: Icon(Icons.audiotrack),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: _isUploadingMedia ? null : _handlePickAudio,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Audio'),
                    ),
                  ],
                ),
                if (_coverUrlController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Audio Preview (Before Publishing):',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AudioPlayerWidget(
                    audioUrl: _coverUrlController.text.trim(),
                    title: _titleController.text.isEmpty
                        ? 'Audio Preview'
                        : _titleController.text,
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // MULTI-IMAGE GALLERY SECTION
              if (_selectedType == 'image') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gallery Images (${_galleryItems.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed:
                          _isUploadingMedia ? null : _handlePickGalleryImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add Images'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_galleryItems.isEmpty)
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('No images in gallery yet. Tap "Add Images".'),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _galleryItems.length,
                    onReorder: _reorderGallery,
                    itemBuilder: (context, index) {
                      final item = _galleryItems[index];
                      final isCover =
                          _coverUrlController.text == item.publicUrl;
                      return ListTile(
                        key: ValueKey(item.storagePath),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: item.publicUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text('Image #${index + 1}'),
                            if (isCover) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'COVER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(item.mime),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isCover)
                              TextButton(
                                onPressed: () => _setAsCover(index),
                                child: const Text('Set Cover'),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _removeGalleryItem(index),
                            ),
                            const Icon(Icons.drag_handle),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
              ],

              // TEXT POST COVER IMAGE SECTION
              if (_selectedType == 'text') ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _coverUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Cover Image URL (Optional)',
                          prefixIcon: Icon(Icons.image),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: _isUploadingMedia
                          ? null
                          : () => _handlePickCoverImage(ImageSource.gallery),
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Upload'),
                    ),
                  ],
                ),
                if (_coverUrlController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: _coverUrlController.text.trim(),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // Tags Field
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (e.g. innovation, health, updates)',
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

              // Publish & Schedule Controls
              SwitchListTile(
                title: const Text('Publish Immediately'),
                subtitle: Text(
                  !canPublish
                      ? 'You lack publishing permissions. Saved as draft for review.'
                      : (_publishNow
                          ? 'Visible immediately to all readers'
                          : 'Save as draft or schedule for later'),
                ),
                value: canPublish && _publishNow,
                onChanged: !canPublish
                    ? null
                    : (val) {
                        setState(() {
                          _publishNow = val;
                          if (val) {
                            _isScheduled = false;
                            _scheduledDateTime = null;
                          }
                        });
                      },
              ),
              if (canPublish && !_publishNow) ...[
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(
                      Icons.schedule_rounded,
                      color: _isScheduled ? Colors.purple : null,
                    ),
                    title: Text(
                      _isScheduled && _scheduledDateTime != null
                          ? 'Scheduled: ${DateFormat.yMMMd().add_jm().format(_scheduledDateTime!)}'
                          : 'Schedule for Later',
                    ),
                    subtitle: Text(
                      _isScheduled
                          ? 'Will automatically publish at scheduled time'
                          : 'Tap to pick date & time for automated publishing',
                    ),
                    trailing: _isScheduled
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            tooltip: 'Cancel Schedule',
                            onPressed: () {
                              setState(() {
                                _isScheduled = false;
                                _scheduledDateTime = null;
                              });
                            },
                          )
                        : const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _pickScheduleDateTime,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
