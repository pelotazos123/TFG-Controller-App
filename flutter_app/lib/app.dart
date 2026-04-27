import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_rccontroller_app/l10n/app_localizations.dart';
import 'package:flutter_rccontroller_app/features/control/control_page.dart';
import 'theme_provider.dart';
import 'locale_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  static final ThemeProvider _themeProvider = ThemeProvider();
  static final LocaleProvider _localeProvider = LocaleProvider();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_themeProvider, _localeProvider]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) {
            return AppLocalizations.of(context)?.appTitle ?? 'RC Controller';
          },
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('es'),
          ],
          locale: _localeProvider.locale,
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
          home: ControlPage(
            themeProvider: _themeProvider,
            localeProvider: _localeProvider,
          ),
        );
      },
    );
  }
}
