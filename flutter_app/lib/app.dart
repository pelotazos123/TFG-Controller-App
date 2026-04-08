import 'package:flutter/material.dart';
import 'package:flutter_rccontroller_app/features/control/control_page.dart';
import 'theme_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  static final ThemeProvider _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeProvider,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'RC Controller',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: _themeProvider.themeMode,
          home: ControlPage(themeProvider: _themeProvider),
        );
      },
    );
  }
}
