// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i10;
import 'package:flutter/material.dart' as _i14;
import 'package:melodrift/domain/entities/album.dart' as _i12;
import 'package:melodrift/domain/entities/mood_category.dart' as _i13;
import 'package:melodrift/domain/entities/song.dart' as _i11;
import 'package:melodrift/presentation/screens/details_screen.dart' as _i1;
import 'package:melodrift/presentation/screens/find_screen.dart' as _i2;
import 'package:melodrift/presentation/screens/home_screen.dart' as _i3;
import 'package:melodrift/presentation/screens/library_screen.dart' as _i4;
import 'package:melodrift/presentation/screens/listen_together_screen.dart'
    as _i5;
import 'package:melodrift/presentation/screens/main_layout.dart' as _i6;
import 'package:melodrift/presentation/screens/player_screen.dart' as _i7;
import 'package:melodrift/presentation/screens/search_screen.dart' as _i8;
import 'package:melodrift/presentation/screens/settings_screen.dart' as _i9;

abstract class $AppRouter extends _i10.RootStackRouter {
  $AppRouter({super.navigatorKey});

  @override
  final Map<String, _i10.PageFactory> pagesMap = {
    DetailsRoute.name: (routeData) {
      final args = routeData.argsAs<DetailsRouteArgs>();
      return _i10.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: _i1.DetailsScreen(
          id: args.id,
          title: args.title,
          type: args.type,
          artworkUrl: args.artworkUrl,
          preloadedSongs: args.preloadedSongs,
          preloadedAlbums: args.preloadedAlbums,
          preloadedMoods: args.preloadedMoods,
          key: args.key,
        ),
      );
    },
    FindRoute.name: (routeData) {
      return _i10.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i2.FindScreen(),
      );
    },
    HomeRoute.name: (routeData) {
      return _i10.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i3.HomeScreen(),
      );
    },
    LibraryRoute.name: (routeData) {
      return _i10.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i4.LibraryScreen(),
      );
    },
    ListenTogetherRoute.name: (routeData) {
      return _i10.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i5.ListenTogetherScreen(),
      );
    },
    MainLayoutRoute.name: (routeData) {
      return _i10.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i6.MainLayoutScreen(),
      );
    },
    PlayerRoute.name: (routeData) {
      return _i10.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i7.PlayerScreen(),
      );
    },
    SearchRoute.name: (routeData) {
      return _i10.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i8.SearchScreen(),
      );
    },
    SettingsRoute.name: (routeData) {
      return _i10.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i9.SettingsScreen(),
      );
    },
  };
}

/// generated route for
/// [_i1.DetailsScreen]
class DetailsRoute extends _i10.PageRouteInfo<DetailsRouteArgs> {
  DetailsRoute({
    required String id,
    required String title,
    required String type,
    String artworkUrl = '',
    List<_i11.Song>? preloadedSongs,
    List<_i12.Album>? preloadedAlbums,
    List<_i13.MoodCategory>? preloadedMoods,
    _i14.Key? key,
    List<_i10.PageRouteInfo>? children,
  }) : super(
          DetailsRoute.name,
          args: DetailsRouteArgs(
            id: id,
            title: title,
            type: type,
            artworkUrl: artworkUrl,
            preloadedSongs: preloadedSongs,
            preloadedAlbums: preloadedAlbums,
            preloadedMoods: preloadedMoods,
            key: key,
          ),
          initialChildren: children,
        );

  static const String name = 'DetailsRoute';

  static const _i10.PageInfo<DetailsRouteArgs> page =
      _i10.PageInfo<DetailsRouteArgs>(name);
}

class DetailsRouteArgs {
  const DetailsRouteArgs({
    required this.id,
    required this.title,
    required this.type,
    this.artworkUrl = '',
    this.preloadedSongs,
    this.preloadedAlbums,
    this.preloadedMoods,
    this.key,
  });

  final String id;

  final String title;

  final String type;

  final String artworkUrl;

  final List<_i11.Song>? preloadedSongs;

  final List<_i12.Album>? preloadedAlbums;

  final List<_i13.MoodCategory>? preloadedMoods;

  final _i14.Key? key;

  @override
  String toString() {
    return 'DetailsRouteArgs{id: $id, title: $title, type: $type, artworkUrl: $artworkUrl, preloadedSongs: $preloadedSongs, preloadedAlbums: $preloadedAlbums, preloadedMoods: $preloadedMoods, key: $key}';
  }
}

/// generated route for
/// [_i2.FindScreen]
class FindRoute extends _i10.PageRouteInfo<void> {
  const FindRoute({List<_i10.PageRouteInfo>? children})
      : super(
          FindRoute.name,
          initialChildren: children,
        );

  static const String name = 'FindRoute';

  static const _i10.PageInfo<void> page = _i10.PageInfo<void>(name);
}

/// generated route for
/// [_i3.HomeScreen]
class HomeRoute extends _i10.PageRouteInfo<void> {
  const HomeRoute({List<_i10.PageRouteInfo>? children})
      : super(
          HomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'HomeRoute';

  static const _i10.PageInfo<void> page = _i10.PageInfo<void>(name);
}

/// generated route for
/// [_i4.LibraryScreen]
class LibraryRoute extends _i10.PageRouteInfo<void> {
  const LibraryRoute({List<_i10.PageRouteInfo>? children})
      : super(
          LibraryRoute.name,
          initialChildren: children,
        );

  static const String name = 'LibraryRoute';

  static const _i10.PageInfo<void> page = _i10.PageInfo<void>(name);
}

/// generated route for
/// [_i5.ListenTogetherScreen]
class ListenTogetherRoute extends _i10.PageRouteInfo<void> {
  const ListenTogetherRoute({List<_i10.PageRouteInfo>? children})
      : super(
          ListenTogetherRoute.name,
          initialChildren: children,
        );

  static const String name = 'ListenTogetherRoute';

  static const _i10.PageInfo<void> page = _i10.PageInfo<void>(name);
}

/// generated route for
/// [_i6.MainLayoutScreen]
class MainLayoutRoute extends _i10.PageRouteInfo<void> {
  const MainLayoutRoute({List<_i10.PageRouteInfo>? children})
      : super(
          MainLayoutRoute.name,
          initialChildren: children,
        );

  static const String name = 'MainLayoutRoute';

  static const _i10.PageInfo<void> page = _i10.PageInfo<void>(name);
}

/// generated route for
/// [_i7.PlayerScreen]
class PlayerRoute extends _i10.PageRouteInfo<void> {
  const PlayerRoute({List<_i10.PageRouteInfo>? children})
      : super(
          PlayerRoute.name,
          initialChildren: children,
        );

  static const String name = 'PlayerRoute';

  static const _i10.PageInfo<void> page = _i10.PageInfo<void>(name);
}

/// generated route for
/// [_i8.SearchScreen]
class SearchRoute extends _i10.PageRouteInfo<void> {
  const SearchRoute({List<_i10.PageRouteInfo>? children})
      : super(
          SearchRoute.name,
          initialChildren: children,
        );

  static const String name = 'SearchRoute';

  static const _i10.PageInfo<void> page = _i10.PageInfo<void>(name);
}

/// generated route for
/// [_i9.SettingsScreen]
class SettingsRoute extends _i10.PageRouteInfo<void> {
  const SettingsRoute({List<_i10.PageRouteInfo>? children})
      : super(
          SettingsRoute.name,
          initialChildren: children,
        );

  static const String name = 'SettingsRoute';

  static const _i10.PageInfo<void> page = _i10.PageInfo<void>(name);
}
