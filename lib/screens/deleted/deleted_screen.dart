import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/deletion_events.dart';
import '../../services/database_service.dart';
import '../../widgets/empty_state.dart';

class DeletedScreen extends StatefulWidget {
  const DeletedScreen({super.key});

  @override
  State<DeletedScreen> createState() => DeletedScreenState();
}

class DeletedScreenState extends State<DeletedScreen> {
  List<String> _thumbnailPaths = [];
  bool _loading = true;
  DeletionEvents? _deletionEvents;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deletionEvents = context.read<DeletionEvents>();
      _deletionEvents!.addListener(_onDeletionChanged);
      reload();
    });
  }

  @override
  void dispose() {
    _deletionEvents?.removeListener(_onDeletionChanged);
    super.dispose();
  }

  void _onDeletionChanged() {
    reload();
  }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final records = await DatabaseService.instance.getDeletionRecords();
    final paths = <String>[];
    for (final record in records) {
      final path = record.thumbnailPath;
      if (path != null && await File(path).exists()) {
        paths.add(path);
      }
    }

    if (!mounted) return;
    setState(() {
      _thumbnailPaths = paths;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _thumbnailPaths.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_thumbnailPaths.isEmpty) {
      return RefreshIndicator(
        onRefresh: reload,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateView(
                icon: Icons.delete_outline,
                title: 'Nothing deleted yet',
                subtitle: 'Photos you trash while sorting will appear here.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: reload,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: _thumbnailPaths.length,
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              File(_thumbnailPaths[index]),
              key: ValueKey(_thumbnailPaths[index]),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
