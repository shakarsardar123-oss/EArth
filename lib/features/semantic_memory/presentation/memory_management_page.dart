/// memory_management_page.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Main UI page for managing semantic memories.
/// Kurdish-first, full RTL layout.
///
/// Features:
///   - List all memories with type badges
///   - Search/recall memories
///   - Filter by memory type
///   - Add new memory
///   - View memory details
///   - Delete (forget) a memory
///
/// Uses the existing S / SEn / SKu localization pattern with
/// memory_ prefix keys.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/memory_entry.dart';
import '../domain/models/memory_type.dart';
import '../application/memory_providers.dart';
import '../application/memory_state.dart';
import '../../../core/localization/s_strings.dart';

/// Main page for semantic memory management.
class MemoryManagementPage extends ConsumerStatefulWidget {
  const MemoryManagementPage({super.key});

  @override
  ConsumerState<MemoryManagementPage> createState() =>
      _MemoryManagementPageState();
}

class _MemoryManagementPageState extends ConsumerState<MemoryManagementPage> {
  final _searchController = TextEditingController();
  final _contentController = TextEditingController();
  MemoryType? _selectedFilter;

  @override
  void initState() {
    super.initState();
    // Load memories on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(memoryStateProvider.notifier).loadMemories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoryStateProvider);
    final s = SStrings.current;

    return Directionality(
      // RTL for Kurdish-first design.
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.memory_pageTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: s.memory_addNew,
              onPressed: () => _showAddDialog(context),
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Search bar ─────────────────────────────────────────
            _buildSearchBar(s),

            // ── Type filter chips ──────────────────────────────────
            _buildFilterChips(s),

            // ── Failure banner ──────────────────────────────────────
            if (state.hasFailure)
              _buildFailureBanner(state.failure!, s),

            // ── Loading indicator ──────────────────────────────────
            if (state.isLoading)
              const LinearProgressIndicator(),

            // ── Memory list ───────────────────────────────────────
            Expanded(
              child: _buildMemoryList(state, s),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Search bar ──────────────────────────────────────────────────

  Widget _buildSearchBar(S s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: s.memory_searchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(memoryStateProvider.notifier).clearSearch();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onSubmitted: (query) {
          if (query.isNotEmpty) {
            ref.read(memoryStateProvider.notifier).search(query);
          }
        },
      ),
    );
  }

  // ─── Filter chips ────────────────────────────────────────────────

  Widget _buildFilterChips(S s) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(s.memory_filterAll),
              selected: _selectedFilter == null,
              onSelected: (_) {
                setState(() => _selectedFilter = null);
                ref.read(memoryStateProvider.notifier).setFilter(null);
              },
            ),
          ),
          for (final type in MemoryType.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(_typeLabel(type, s)),
                selected: _selectedFilter == type,
                onSelected: (_) {
                  setState(() => _selectedFilter = type);
                  ref.read(memoryStateProvider.notifier).setFilter(type);
                },
              ),
            ),
        ],
      ),
    );
  }

  // ─── Failure banner ──────────────────────────────────────────────

  Widget _buildFailureBanner(MemoryFailure failure, S s) {
    return MaterialBanner(
      content: Text('${s.memory_errorPrefix}: ${failure.detail}'),
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      actions: [
        TextButton(
          onPressed: () {
            ref.read(memoryStateProvider.notifier).loadMemories();
          },
          child: Text(s.memory_retry),
        ),
      ],
    );
  }

  // ─── Memory list ────────────────────────────────────────────────

  Widget _buildMemoryList(MemoryState state, S s) {
    final displayMemories =
        state.isSearching ? state.searchResults : state.filteredMemories;

    if (displayMemories.isEmpty) {
      return Center(
        child: Text(
          state.isSearching ? s.memory_noSearchResults : s.memory_emptyMessage,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: displayMemories.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final memory = displayMemories[index];
        return _MemoryCard(
          memory: memory,
          onTap: () => _showDetailDialog(context, memory, s),
          onForget: () => _confirmForget(context, memory, s),
          localizer: s,
        );
      },
    );
  }

  // ─── Add memory dialog ───────────────────────────────────────────

  void _showAddDialog(BuildContext context) {
    final s = SStrings.current;
    MemoryType selectedType = MemoryType.conversation;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInnerState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: Text(s.memory_addNew),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        labelText: s.memory_contentLabel,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<MemoryType>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: s.memory_typeLabel,
                      ),
                      items: MemoryType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(_typeLabel(t, s)),
                              ))
                          .toList(),
                      onChanged: (t) {
                        if (t != null) {
                          setInnerState(() => selectedType = t);
                        }
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(s.memory_cancel),
                  ),
                  FilledButton(
                    onPressed: () {
                      final content = _contentController.text.trim();
                      if (content.isNotEmpty) {
                        ref.read(memoryStateProvider.notifier).rememberMemory(
                              content: content,
                              type: selectedType,
                            );
                        _contentController.clear();
                        Navigator.pop(ctx);
                      }
                    },
                    child: Text(s.memory_save),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Detail dialog ───────────────────────────────────────────────

  void _showDetailDialog(BuildContext context, MemoryEntry memory, S s) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(_typeLabel(memory.memoryType, s)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(memory.content),
              const SizedBox(height: 8),
              Text(
                '${s.memory_importance}: ${memory.importance.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${s.memory_source}: ${memory.source}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${s.memory_created}: ${_formatDate(memory.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!memory.isActive)
                Text(
                  s.memory_inactive,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.memory_close),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Forget confirmation ────────────────────────────────────────

  void _confirmForget(BuildContext context, MemoryEntry memory, S s) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(s.memory_forgetConfirmTitle),
          content: Text(
            '${s.memory_forgetConfirmMessage}\n\n"${memory.content}"',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.memory_cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                ref
                    .read(memoryStateProvider.notifier)
                    .forgetMemory(memory.id);
                Navigator.pop(ctx);
              },
              child: Text(s.memory_forget),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  String _typeLabel(MemoryType type, S s) {
    switch (type) {
      case MemoryType.userPreference:
        return s.memory_typeUserPreference;
      case MemoryType.personalFact:
        return s.memory_typePersonalFact;
      case MemoryType.conversation:
        return s.memory_typeConversation;
      case MemoryType.task:
        return s.memory_typeTask;
      case MemoryType.project:
        return s.memory_typeProject;
      case MemoryType.device:
        return s.memory_typeDevice;
      case MemoryType.location:
        return s.memory_typeLocation;
      case MemoryType.instruction:
        return s.memory_typeInstruction;
      case MemoryType.other:
        return s.memory_typeOther;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ─── Memory card widget ─────────────────────────────────────────────

class _MemoryCard extends StatelessWidget {
  final MemoryEntry memory;
  final VoidCallback onTap;
  final VoidCallback onForget;
  final S localizer;

  const _MemoryCard({
    required this.memory,
    required this.onTap,
    required this.onForget,
    required this.localizer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: memory.isHighImportance
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            _typeIcon(memory.memoryType),
            size: 20,
          ),
        ),
        title: Text(
          memory.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _typeLabel(memory.memoryType),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: localizer.memory_forget,
          onPressed: onForget,
        ),
      ),
    );
  }

  String _typeLabel(MemoryType type) {
    switch (type) {
      case MemoryType.userPreference:
        return localizer.memory_typeUserPreference;
      case MemoryType.personalFact:
        return localizer.memory_typePersonalFact;
      case MemoryType.conversation:
        return localizer.memory_typeConversation;
      case MemoryType.task:
        return localizer.memory_typeTask;
      case MemoryType.project:
        return localizer.memory_typeProject;
      case MemoryType.device:
        return localizer.memory_typeDevice;
      case MemoryType.location:
        return localizer.memory_typeLocation;
      case MemoryType.instruction:
        return localizer.memory_typeInstruction;
      case MemoryType.other:
        return localizer.memory_typeOther;
    }
  }

  IconData _typeIcon(MemoryType type) {
    switch (type) {
      case MemoryType.userPreference:
        return Icons.thumb_up_outlined;
      case MemoryType.personalFact:
        return Icons.person_outlined;
      case MemoryType.conversation:
        return Icons.chat_outlined;
      case MemoryType.task:
        return Icons.check_circle_outlined;
      case MemoryType.project:
        return Icons.folder_outlined;
      case MemoryType.device:
        return Icons.devices_outlined;
      case MemoryType.location:
        return Icons.location_on_outlined;
      case MemoryType.instruction:
        return Icons.rule_outlined;
      case MemoryType.other:
        return Icons.more_horiz;
    }
  }
}
