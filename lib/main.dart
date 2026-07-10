import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features/agent/sgp_agent_screen.dart';
import 'features/agent/sgp_app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: SgpAppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SgpAgentApp());
}

class SgpAgentApp extends StatelessWidget {
  const SgpAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SGP-Agent',
      debugShowCheckedModeBanner: false,
      theme: SgpAppTheme.dark,
      home: const SgpAgentHome(),
    );
  }
}
