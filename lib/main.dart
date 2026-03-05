import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/apps_provider.dart';
import 'providers/downloads_provider.dart';
import 'screens/main_scaffold.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const PremiumAppStore());
}

class PremiumAppStore extends StatelessWidget {
  const PremiumAppStore({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppsProvider()),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
      ],
      child: MaterialApp(
        title: 'AppStore',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const MainScaffold(),
      ),
    );
  }
}
