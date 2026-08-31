import 'package:flutter/material.dart';

import 'analytics/analytics_screen.dart';
import 'deleted/deleted_screen.dart';
import 'gallery/album_list_screen.dart';
import 'home/home_screen.dart';
import 'settings/settings_screen.dart';
import '../widgets/fade_page_route.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _homeKey = GlobalKey<HomeScreenState>();
  final _galleryKey = GlobalKey<AlbumListScreenState>();
  final _deletedKey = GlobalKey<DeletedScreenState>();
  final _analyticsKey = GlobalKey<AnalyticsScreenState>();

  static const _tabs = [
    _TabSpec(
      label: 'Home',
      outlinedIcon: Icons.home_outlined,
      filledIcon: Icons.home,
    ),
    _TabSpec(
      label: 'Gallery',
      outlinedIcon: Icons.photo_library_outlined,
      filledIcon: Icons.photo_library,
    ),
    _TabSpec(
      label: 'Deleted',
      outlinedIcon: Icons.delete_outline,
      filledIcon: Icons.delete,
    ),
    _TabSpec(
      label: 'Analytics',
      outlinedIcon: Icons.bar_chart_outlined,
      filledIcon: Icons.bar_chart,
    ),
  ];

  void _onTabSelected(int index) {
    setState(() => _index = index);
    if (index == 0) {
      _homeKey.currentState?.reload(silent: true);
    } else if (index == 1) {
      _galleryKey.currentState?.reload(silent: true);
    } else if (index == 2) {
      _deletedKey.currentState?.reload();
    } else if (index == 3) {
      _analyticsKey.currentState?.reload();
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      FadePageRoute<void>(page: const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabs[_index].label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            key: _homeKey,
            onBrowseFolders: () => _onTabSelected(1),
          ),
          AlbumListScreen(key: _galleryKey),
          DeletedScreen(key: _deletedKey),
          AnalyticsScreen(key: _analyticsKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTabSelected,
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.outlinedIcon),
              selectedIcon: Icon(tab.filledIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec({
    required this.label,
    required this.outlinedIcon,
    required this.filledIcon,
  });

  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;
}
