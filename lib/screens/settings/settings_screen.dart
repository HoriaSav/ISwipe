import 'dart:io';

import 'package:flutter/material.dart';

import '../../providers/app_services.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SettingsSection(
            title: 'About',
            children: [
              ListTile(
                leading: Icon(Icons.auto_awesome_outlined, color: scheme.primary),
                title: const Text('ISwipe'),
                subtitle: const Text('Clean up your photo library, one swipe at a time.'),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Trash',
            children: [
              const ListTile(
                leading: Icon(Icons.delete_sweep_outlined),
                title: Text('How deletes work'),
                subtitle: Text(
                  'Deletes are queued while sorting and sent to trash in one '
                  'batch when you close. Files expire per OS rules (~30 days).',
                ),
              ),
            ],
          ),
          if (Platform.isAndroid)
            _SettingsSection(
              title: 'Android',
              children: [
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Media management'),
                  subtitle: const Text(
                    'Optional system access to reduce delete prompts. '
                    'Not available on all devices.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.galleryService.openManageMediaSettings();
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }
}
