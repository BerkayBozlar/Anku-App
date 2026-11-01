import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_screen.dart';
import '../../features/auth/auth_models.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/session_controller.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/map/campus_map_screen.dart';
import '../../features/profile/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Oturum değişince yönlendirme kuralları yeniden çalışsın
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(sessionProvider), state.matchedLocation),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          for (final tab in _tabs)
            StatefulShellBranch(
              routes: [GoRoute(path: tab.path, builder: tab.builder)],
            ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Giriş durumu ve role göre yönlendirme. `null` dönerse istenen sayfa açılır.
String? authRedirect(AsyncValue<AuthSession?> session, String location) {
  if (session.isLoading && !session.hasValue) {
    return location == '/splash' ? null : '/splash';
  }

  final user = session.value?.user;
  final onAuthPage = location == '/login' || location == '/register';

  if (user == null) return onAuthPage ? null : '/login';
  if (onAuthPage || location == '/splash') return '/';

  final tab = _tabs.where((t) => location.startsWith(t.path) && t.path != '/');
  if (tab.isNotEmpty && !tab.first.isVisibleTo(user.role)) return '/';
  return null;
}

class _Tab {
  const _Tab({
    required this.path,
    required this.builder,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.roles,
  });

  final String path;
  final GoRouterWidgetBuilder builder;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// `null` ise herkese açık.
  final Set<UserRole>? roles;

  bool isVisibleTo(UserRole role) => roles == null || roles!.contains(role);
}

final _tabs = <_Tab>[
  _Tab(
    path: '/',
    builder: (context, state) => const HomeScreen(),
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Ana Sayfa',
  ),
  _Tab(
    path: '/map',
    builder: (context, state) => const CampusMapScreen(),
    icon: Icons.map_outlined,
    selectedIcon: Icons.map,
    label: 'Harita',
  ),
  _Tab(
    path: '/admin',
    builder: (context, state) => const AdminScreen(),
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
    label: 'Yönetim',
    roles: {UserRole.yonetici},
  ),
  _Tab(
    path: '/profile',
    builder: (context, state) => const ProfileScreen(),
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: 'Profil',
  ),
];

/// Alt gezinme çubuğu; sekmeler kullanıcının rolüne göre gösterilir.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(sessionProvider).value?.user.role ?? UserRole.ogrenci;

    // Görünen sekme sırası -> shell branch sırası
    final visible = [
      for (var i = 0; i < _tabs.length; i++)
        if (_tabs[i].isVisibleTo(role)) i,
    ];
    final selected = visible.indexOf(navigationShell.currentIndex);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (index) {
          final branch = visible[index];
          navigationShell.goBranch(
            branch,
            initialLocation: branch == navigationShell.currentIndex,
          );
        },
        destinations: [
          for (final i in visible)
            NavigationDestination(
              icon: Icon(_tabs[i].icon),
              selectedIcon: Icon(_tabs[i].selectedIcon),
              label: _tabs[i].label,
            ),
        ],
      ),
    );
  }
}
