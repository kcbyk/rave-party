import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/registration_screen.dart';
import 'theme/app_theme.dart';

import 'services/api_service.dart';
import 'services/mock_data_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MockDataService.initializeIdentity();
  final registered = await MockDataService.isRegistered();
  
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
  if (registered) ApiService().syncUserProfile();

  runApp(RavePartyApp(registered: registered));
}

class RavePartyApp extends StatelessWidget {
  const RavePartyApp({super.key, this.registered = true});
  final bool registered;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rave Stream Party',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: registered ? const MainNavigationScreen() : const RegistrationScreen(),
    );
  }
}
