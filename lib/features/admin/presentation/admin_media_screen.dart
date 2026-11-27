import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../blog/data/blog_storage_service.dart';
import '../../blog/presentation/widgets/audio_player_widget.dart';

final adminMediaListProvider = FutureProvider.autoDispose<List<FileObject>>((
  ref,
) async {
  final storage = ref.watch(blogStorageServiceProvider);
  return storage.listAllMediaFiles();
});

class AdminMediaScreen extends ConsumerStatefulWidget {
  const AdminMediaScreen({super.key});

  @override
  ConsumerState<AdminMediaScreen> createState() => _AdminMediaScreenState();
}

class _AdminMediaScreenState extends ConsumerState<AdminMediaScreen> {
  String _filter = 'all'; // 'all', 'images', 'audio'

  Future<void> _handleDelete(FileObject file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Storage Media'),
        content: Text(
          'Are you sure you want to permanently delete "${file.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(blogStorageServiceProvider).deleteStorageFiles([
          file.name,
        ]);
        ref.invalidate(adminMediaListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File removed from storage.')),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  void _showPreviewDialog(
    BuildContext context,
    FileObject file,
    String publicUrl,
  ) {
    final isAudio =
        file.name.endsWith('.mp3') ||
        file.name.endsWith('.m4a') ||
        file.name.endsWith('.wav');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(file.name, style: const TextStyle(fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          child: isAudio
              ? AudioPlayerWidget(audioUrl: publicUrl, title: file.name)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: publicUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const SizedBox(
                      height: 150,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => const SizedBox(
                      height: 100,
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReplace(FileObject file) async {
    final isAudio =
        file.name.endsWith('.mp3') ||
        file.name.endsWith('.m4a') ||
        file.name.endsWith('.wav');

    if (isAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Audio replacement: upload a new audio file in post editor.',
          ),
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    try {
      final rawBytes = await img.readAsBytes();
      final ext = img.name.split('.').last.toLowerCase();
      BlogStorageService.validateImageFile(img.name, rawBytes.lengthInBytes);

      final mimeType = BlogStorageService.imageMimeMap[ext] ?? 'image/jpeg';
      final compressedBytes = await ref
          .read(blogStorageServiceProvider)
          .compressImageBytes(rawBytes, ext);

      // Overwrite file in bucket
      final client = ref.read(blogStorageServiceProvider);
      // Delete old and upload replacement
      await client.deleteStorageFiles([file.name]);
      await client.uploadImageBytes(
        authorId: file.name.contains('/')
            ? file.name.split('/').first
            : 'admin',
        fileName: img.name,
        bytes: compressedBytes,
        mimeType: mimeType,
      );

      ref.invalidate(adminMediaListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File replaced successfully.')),
        );
      }
    } catch (e) {
      if (mounted) ErrorHandler.showSnackBar(context, e);
    }
  }

  String _formatBytes(num? bytes) {
    if (bytes == null || bytes == 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(adminMediaListProvider);
    final theme = Theme.of(context);
    final supabaseUrl = ref.watch(blogStorageServiceProvider).supabaseUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminMediaListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Files'),
                  selected: _filter == 'all',
                  onSelected: (val) => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Images'),
                  selected: _filter == 'images',
                  onSelected: (val) => setState(() => _filter = 'images'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Audio'),
                  selected: _filter == 'audio',
                  onSelected: (val) => setState(() => _filter = 'audio'),
                ),
              ],
            ),
          ),

          // File List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminMediaListProvider),
              child: mediaAsync.when(
                loading: () =>
                    const LoadingIndicator(message: 'Loading media...'),
                error: (e, stack) => ErrorView(
                  message: 'Unable to load storage media',
                  onRetry: () => ref.invalidate(adminMediaListProvider),
                ),
                data: (files) {
                  final filtered = files.where((f) {
                    final isAudio =
                        f.name.endsWith('.mp3') ||
                        f.name.endsWith('.m4a') ||
                        f.name.endsWith('.wav');
                    if (_filter == 'images') return !isAudio;
                    if (_filter == 'audio') return isAudio;
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.perm_media_outlined,
                      title: 'No Media Files Found',
                      subtitle: 'Uploaded post images and audio files will appear here.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final file = filtered[index];
                      final isAudio =
                          file.name.endsWith('.mp3') ||
                          file.name.endsWith('.m4a') ||
                          file.name.endsWith('.wav');
                      final publicUrl =
                          '$supabaseUrl/storage/v1/object/public/blog-media/${file.name}';

                      return Card(
                        child: ListTile(
                          leading: isAudio
                              ? CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: const Icon(Icons.audiotrack),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CachedNetworkImage(
                                    imageUrl: publicUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 48,
                                      height: 48,
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.image_outlined),
                                  ),
                                ),
                          title: Text(
                            file.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Size: ${_formatBytes(file.metadata?['size'] as num?)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined),
                                tooltip: 'Preview',
                                onPressed: () => _showPreviewDialog(
                                  context,
                                  file,
                                  publicUrl,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.swap_horiz_rounded),
                                tooltip: 'Replace File',
                                onPressed: () => _handleReplace(file),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete File',
                                onPressed: () => _handleDelete(file),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
