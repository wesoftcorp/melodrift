import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'flavors.dart';
import 'core/theme/theme_provider.dart';
import 'app/router/app_router.dart';

final appRouterHelperProvider = Provider<AppRouter>((ref) {
  return AppRouter();
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final appRouter = ref.watch(appRouterHelperProvider);

    ThemeMode flutterThemeMode = ThemeMode.system;

    switch (themeMode) {
      case AppThemeMode.light:
        flutterThemeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
        flutterThemeMode = ThemeMode.dark;
        break;
      case AppThemeMode.amoled:
        flutterThemeMode = ThemeMode.dark;
        break;
      case AppThemeMode.system:
        flutterThemeMode = ThemeMode.system;
        break;
    }

    return MaterialApp.router(
      title: F.title,
      theme: AppTheme.lightTheme,
      darkTheme: themeMode == AppThemeMode.amoled ? AppTheme.amoledTheme : AppTheme.darkTheme,
      themeMode: flutterThemeMode,
      routerConfig: appRouter.config(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return _flavorBanner(child: child ?? const SizedBox(), show: kDebugMode);
      },
    );
  }

  Widget _flavorBanner({required Widget child, bool show = true}) => show
      ? Banner(
          location: BannerLocation.topStart,
          message: F.name,
          color: Colors.green.withAlpha(150),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.0,
            letterSpacing: 1.0,
          ),
          textDirection: TextDirection.ltr,
          child: child,
        )
      : child;
}
