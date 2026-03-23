import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.bg,
  ));
  runApp(const IlyassTvApp());
}

class IlyassTvApp extends StatelessWidget {
  const IlyassTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ilyass tv',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
