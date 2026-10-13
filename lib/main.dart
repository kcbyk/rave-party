import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/app_theme.dart';

import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Dikey yönelimi sabitle (Rave tarzı dikey mobil deneyimi için)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Şeffaf durum çubuğu ve koyu navigation bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Kullanıcı profilini backend ile senkronize et
  ApiService().syncUserProfile();

  runApp(const RavePartyApp());
}

class RavePartyApp extends StatelessWidget {
  const RavePartyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rave Stream Party',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}
