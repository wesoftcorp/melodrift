import 'package:auto_route/auto_route.dart';
import 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends $AppRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          path: '/',
          page: MainLayoutRoute.page,
          children: [
            RedirectRoute(path: '', redirectTo: 'home'),
            AutoRoute(path: 'home', page: HomeRoute.page),
            AutoRoute(path: 'search', page: SearchRoute.page),
            AutoRoute(path: 'library', page: LibraryRoute.page),
            AutoRoute(path: 'settings', page: SettingsRoute.page),
          ],
        ),
        AutoRoute(path: '/player', page: PlayerRoute.page, fullscreenDialog: true),
        AutoRoute(path: '/details', page: DetailsRoute.page),
        AutoRoute(path: '/find', page: FindRoute.page),
        AutoRoute(path: '/listen-together', page: ListenTogetherRoute.page),
      ];
}
