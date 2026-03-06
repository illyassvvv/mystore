import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/apps_provider.dart';
import 'providers/downloads_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/main_scaffold.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  final appsProvider = AppsProvider();
  await appsProvider.init();

  final downloadsProvider = DownloadsProvider();
  await downloadsProvider.init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: appsProvider),
        ChangeNotifierProvider.value(value: downloadsProvider),
      ],
      child: const PremiumAppStore(),
    ),
  );
}

class PremiumAppStore extends StatelessWidget {
  const PremiumAppStore({super.key});

  @override
  Widget build(BuildContext context) {
    final themeP = context.watch<ThemeProvider>();
    final t = AppTheme(themeP.isDark);

    // Use CupertinoApp at root so CupertinoPageRoute swipe-back works everywhere
    return CupertinoApp(
      title: 'AppStore',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: themeP.isDark ? Brightness.dark : Brightness.light,
        primaryColor: AppColors.accent,
        scaffoldBackgroundColor: t.bg,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.accent,
        ),
      ),
      home: const MainScaffold(),
    );
  }
}
