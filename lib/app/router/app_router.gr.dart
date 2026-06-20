// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i9;
import 'package:melodrift/presentation/screens/find_screen.dart' as _i1;
import 'package:melodrift/presentation/screens/home_screen.dart' as _i2;
import 'package:melodrift/presentation/screens/library_screen.dart' as _i3;
import 'package:melodrift/presentation/screens/listen_together_screen.dart'
    as _i4;
import 'package:melodrift/presentation/screens/main_layout.dart' as _i5;
import 'package:melodrift/presentation/screens/player_screen.dart' as _i6;
import 'package:melodrift/presentation/screens/search_screen.dart' as _i7;
import 'package:melodrift/presentation/screens/settings_screen.dart' as _i8;

abstract class $AppRouter extends _i9.RootStackRouter {
  $AppRouter({super.navigatorKey});

  @override
  final Map<String, _i9.PageFactory> pagesMap = {
    FindRoute.name: (routeData) {
      return _i9.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i1.FindScreen(),
      );
    },
    HomeRoute.name: (routeData) {
      return _i9.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i2.HomeScreen(),
      );
    },
    LibraryRoute.name: (routeData) {
      return _i9.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i3.LibraryScreen(),
      );
    },
    ListenTogetherRoute.name: (routeData) {
      return _i9.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i4.ListenTogetherScreen(),
      );
    },
    MainLayoutRoute.name: (routeData) {
      return _i9.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i5.MainLayoutScreen(),
      );
    },
    PlayerRoute.name: (routeData) {
      return _i9.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i6.PlayerScreen(),
      );
    },
    SearchRoute.name: (routeData) {
      return _i9.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i7.SearchScreen(),
      );
    },
    SettingsRoute.name: (routeData) {
      return _i9.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i8.SettingsScreen(),
      );
    },
  };
}

/// generated route for
/// [_i1.FindScreen]
class FindRoute extends _i9.PageRouteInfo<void> {
  const FindRoute({List<_i9.PageRouteInfo>? children})
      : super(
          FindRoute.name,
          initialChildren: children,
        );

  static const String name = 'FindRoute';

  static const _i9.PageInfo<void> page = _i9.PageInfo<void>(name);
}

/// generated route for
/// [_i2.HomeScreen]
class HomeRoute extends _i9.PageRouteInfo<void> {
  const HomeRoute({List<_i9.PageRouteInfo>? children})
      : super(
          HomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'HomeRoute';

  static const _i9.PageInfo<void> page = _i9.PageInfo<void>(name);
}

/// generated route for
/// [_i3.LibraryScreen]
class LibraryRoute extends _i9.PageRouteInfo<void> {
  const LibraryRoute({List<_i9.PageRouteInfo>? children})
      : super(
          LibraryRoute.name,
          initialChildren: children,
        );

  static const String name = 'LibraryRoute';

  static const _i9.PageInfo<void> page = _i9.PageInfo<void>(name);
}

/// generated route for
/// [_i4.ListenTogetherScreen]
class ListenTogetherRoute extends _i9.PageRouteInfo<void> {
  const ListenTogetherRoute({List<_i9.PageRouteInfo>? children})
      : super(
          ListenTogetherRoute.name,
          initialChildren: children,
        );

  static const String name = 'ListenTogetherRoute';

  static const _i9.PageInfo<void> page = _i9.PageInfo<void>(name);
}

/// generated route for
/// [_i5.MainLayoutScreen]
class MainLayoutRoute extends _i9.PageRouteInfo<void> {
  const MainLayoutRoute({List<_i9.PageRouteInfo>? children})
      : super(
          MainLayoutRoute.name,
          initialChildren: children,
        );

  static const String name = 'MainLayoutRoute';

  static const _i9.PageInfo<void> page = _i9.PageInfo<void>(name);
}

/// generated route for
/// [_i6.PlayerScreen]
class PlayerRoute extends _i9.PageRouteInfo<void> {
  const PlayerRoute({List<_i9.PageRouteInfo>? children})
      : super(
          PlayerRoute.name,
          initialChildren: children,
        );

  static const String name = 'PlayerRoute';

  static const _i9.PageInfo<void> page = _i9.PageInfo<void>(name);
}

/// generated route for
/// [_i7.SearchScreen]
class SearchRoute extends _i9.PageRouteInfo<void> {
  const SearchRoute({List<_i9.PageRouteInfo>? children})
      : super(
          SearchRoute.name,
          initialChildren: children,
        );

  static const String name = 'SearchRoute';

  static const _i9.PageInfo<void> page = _i9.PageInfo<void>(name);
}

/// generated route for
/// [_i8.SettingsScreen]
class SettingsRoute extends _i9.PageRouteInfo<void> {
  const SettingsRoute({List<_i9.PageRouteInfo>? children})
      : super(
          SettingsRoute.name,
          initialChildren: children,
        );

  static const String name = 'SettingsRoute';

  static const _i9.PageInfo<void> page = _i9.PageInfo<void>(name);
}
