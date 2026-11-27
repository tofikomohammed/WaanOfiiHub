import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../blog/data/blog_repository.dart';
import '../../blog/models/blog_category.dart';
import '../../blog/models/blog_tag.dart';

class AdminTaxonomiesScreen extends ConsumerStatefulWidget {
  const AdminTaxonomiesScreen({super.key});

  @override
  ConsumerState<AdminTaxonomiesScreen> createState() =>
      _AdminTaxonomiesScreenState();
}

class _AdminTaxonomiesScreenState extends ConsumerState<AdminTaxonomiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Category Actions ---

  Future<void> _showCreateCategoryDialog() async {
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Science & Nature',
                ),
                onChanged: (val) {
                  slugCtrl.text = val.trim().toLowerCase().replaceAll(
                    RegExp(r'[^a-z0-9]+'),
                    '-',
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: slugCtrl,
                decoration: const InputDecoration(
                  labelText: 'Slug (URL friendly)',
                  hintText: 'e.g. science-nature',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty && mounted) {
      try {
        await ref
            .read(blogRepositoryProvider)
            .createCategory(
              name: nameCtrl.text.trim(),
              slug: slugCtrl.text.trim().toLowerCase(),
              description: descCtrl.text.trim(),
            );
        ref.invalidate(categoriesListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category created successfully!')),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _showRenameCategoryDialog(BlogCategory cat) async {
    final nameCtrl = TextEditingController(text: cat.name);
    final slugCtrl = TextEditingController(text: cat.slug);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rename "${cat.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'New Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: slugCtrl,
              decoration: const InputDecoration(labelText: 'New Slug'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty && mounted) {
      try {
        await ref
            .read(blogRepositoryProvider)
            .renameCategory(
              id: cat.id,
              newName: nameCtrl.text.trim(),
              newSlug: slugCtrl.text.trim().toLowerCase(),
            );
        ref.invalidate(categoriesListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category renamed successfully!')),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _showMergeCategoryDialog(
    BlogCategory sourceCat,
    List<BlogCategory> allCats,
  ) async {
    final availableTargets = allCats
        .where((c) => c.slug != sourceCat.slug)
        .toList();
    if (availableTargets.isEmpty) return;

    String targetSlug = availableTargets.first.slug;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Merge "${sourceCat.name}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All posts currently assigned to "${sourceCat.name}" will be migrated into the target category. "${sourceCat.name}" will then be safely deleted.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: targetSlug,
                decoration: const InputDecoration(labelText: 'Target Category'),
                items: availableTargets.map((c) {
                  return DropdownMenuItem(value: c.slug, child: Text(c.name));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => targetSlug = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Merge & Delete Source'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(blogRepositoryProvider)
            .mergeCategories(
              sourceSlug: sourceCat.slug,
              targetSlug: targetSlug,
            );
        ref.invalidate(categoriesListProvider);
        ref.invalidate(blogFeedProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Categories merged successfully!')),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _showDeleteCategoryDialog(
    BlogCategory cat,
    List<BlogCategory> allCats,
  ) async {
    final fallbacks = allCats.where((c) => c.slug != cat.slug).toList();
    String fallbackSlug = fallbacks.isNotEmpty ? fallbacks.first.slug : 'news';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Delete "${cat.name}" safely'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Existing posts in "${cat.name}" will be reassigned to the fallback category below so no content is orphaned.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: fallbackSlug,
                decoration: const InputDecoration(
                  labelText: 'Fallback Category',
                ),
                items: fallbacks.map((c) {
                  return DropdownMenuItem(value: c.slug, child: Text(c.name));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => fallbackSlug = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Safe Delete'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(blogRepositoryProvider)
            .deleteCategory(slug: cat.slug, fallbackSlug: fallbackSlug);
        ref.invalidate(categoriesListProvider);
        ref.invalidate(blogFeedProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted safely.')),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  // --- Tag Actions ---

  Future<void> _showCreateTagDialog() async {
    final nameCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Tag'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Tag Name',
            hintText: 'e.g. mobile, flutter, organic',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty && mounted) {
      try {
        await ref.read(blogRepositoryProvider).createTag(nameCtrl.text.trim());
        ref.invalidate(tagsListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tag created successfully!')),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _showRenameTagDialog(BlogTag tag) async {
    final nameCtrl = TextEditingController(text: tag.name);
    final slugCtrl = TextEditingController(text: tag.slug);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rename Tag "#${tag.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'New Tag Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: slugCtrl,
              decoration: const InputDecoration(labelText: 'New Slug'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty && mounted) {
      try {
        await ref
            .read(blogRepositoryProvider)
            .renameTag(
              id: tag.id,
              newName: nameCtrl.text.trim(),
              newSlug: slugCtrl.text.trim().toLowerCase(),
            );
        ref.invalidate(tagsListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tag renamed successfully!')),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _showMergeTagDialog(
    BlogTag sourceTag,
    List<BlogTag> allTags,
  ) async {
    final availableTargets = allTags
        .where((t) => t.name != sourceTag.name)
        .toList();
    if (availableTargets.isEmpty) return;

    String targetName = availableTargets.first.name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Merge "#${sourceTag.name}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Posts currently having tag "#${sourceTag.name}" will have it replaced by the target tag. Duplicate tags will be cleanly deduplicated.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: targetName,
                decoration: const InputDecoration(labelText: 'Target Tag'),
                items: availableTargets.map((t) {
                  return DropdownMenuItem(
                    value: t.name,
                    child: Text('#${t.name}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => targetName = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Merge Tags'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(blogRepositoryProvider)
            .mergeTags(sourceName: sourceTag.name, targetName: targetName);
        ref.invalidate(tagsListProvider);
        ref.invalidate(blogFeedProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tags merged successfully!')),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _showDeleteTagDialog(BlogTag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Tag "#${tag.name}"'),
        content: Text(
          'Are you sure you want to delete tag "#${tag.name}"? It will be safely removed from all articles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Tag'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(blogRepositoryProvider).deleteTag(tag.name);
        ref.invalidate(tagsListProvider);
        ref.invalidate(blogFeedProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tag deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) ErrorHandler.showSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesListProvider);
    final tagsAsync = ref.watch(tagsListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories & Tags'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.category_outlined), text: 'Categories'),
            Tab(icon: Icon(Icons.tag_rounded), text: 'Tags'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Categories Tab
          RefreshIndicator(
            onRefresh: () async => ref.invalidate(categoriesListProvider),
            child: catsAsync.when(
              loading: () =>
                  const LoadingIndicator(message: 'Loading categories...'),
              error: (err, stack) => ErrorView(
                message: 'Unable to load categories',
                onRetry: () => ref.invalidate(categoriesListProvider),
              ),
              data: (categories) {
                if (categories.isEmpty) {
                  return const EmptyState(
                    icon: Icons.category_outlined,
                    title: 'No Categories Found',
                    subtitle:
                        'Create your first category using the button below.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: categories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            cat.name.isNotEmpty
                                ? cat.name[0].toUpperCase()
                                : 'C',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          cat.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          cat.description != null && cat.description!.isNotEmpty
                              ? cat.description!
                              : 'Slug: /${cat.slug}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'rename') {
                              _showRenameCategoryDialog(cat);
                            } else if (val == 'merge') {
                              _showMergeCategoryDialog(cat, categories);
                            } else if (val == 'delete') {
                              _showDeleteCategoryDialog(cat, categories);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Rename'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'merge',
                              child: Row(
                                children: [
                                  Icon(Icons.merge_type_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Merge into...'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete safely',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
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

          // Tags Tab
          RefreshIndicator(
            onRefresh: () async => ref.invalidate(tagsListProvider),
            child: tagsAsync.when(
              loading: () => const LoadingIndicator(message: 'Loading tags...'),
              error: (err, stack) => ErrorView(
                message: 'Unable to load tags',
                onRetry: () => ref.invalidate(tagsListProvider),
              ),
              data: (tags) {
                if (tags.isEmpty) {
                  return const EmptyState(
                    icon: Icons.tag_rounded,
                    title: 'No Tags Found',
                    subtitle: 'Create tags using the action button below.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: tags.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          child: const Icon(Icons.tag_rounded, size: 20),
                        ),
                        title: Text(
                          '#${tag.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Slug: ${tag.slug}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'rename') {
                              _showRenameTagDialog(tag);
                            } else if (val == 'merge') {
                              _showMergeTagDialog(tag, tags);
                            } else if (val == 'delete') {
                              _showDeleteTagDialog(tag);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Rename'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'merge',
                              child: Row(
                                children: [
                                  Icon(Icons.merge_type_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Merge into...'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'New Category' : 'New Tag'),
        onPressed: () {
          if (_tabController.index == 0) {
            _showCreateCategoryDialog();
          } else {
            _showCreateTagDialog();
          }
        },
      ),
    );
  }
}
