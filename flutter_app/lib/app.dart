import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_rccontroller_app/features/control/control_page.dart';
import 'package:flutter_rccontroller_app/l10n/app_localizations.dart';

import 'locale_provider.dart';
import 'theme_provider.dart';

class App extends StatefulWidget {
  const App({super.key});

  static final ThemeProvider _themeProvider = ThemeProvider();
  static final LocaleProvider _localeProvider = LocaleProvider();

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with SingleTickerProviderStateMixin {
  static const Duration _splashDuration = Duration(milliseconds: 1200);

  late final AnimationController _splashController;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _splashController = AnimationController(
      vsync: this,
      duration: _splashDuration,
    )..addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) {
          return;
        }

        setState(() {
          _showSplash = false;
        });
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _splashController.forward();
    });
  }

  @override
  void dispose() {
    _splashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        App._themeProvider,
        App._localeProvider,
      ]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
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
          locale: App._localeProvider.locale,
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
          themeMode: App._themeProvider.themeMode,
          home: _showSplash
              ? _SplashTransition(animation: _splashController)
              : ControlPage(
                  themeProvider: App._themeProvider,
                  localeProvider: App._localeProvider,
                ),
        );
      },
    );
  }
}

class _SplashTransition extends StatelessWidget {
  const _SplashTransition({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ).value;

        return Opacity(
          opacity: 1.0 - fade,
          child: Transform.scale(
            scale: 0.96 + (0.04 * (1.0 - fade)),
            child: const _WelcomeSplashPage(),
          ),
        );
      },
    );
  }
}

class _WelcomeSplashPage extends StatelessWidget {
  const _WelcomeSplashPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F5B3B),
              const Color(0xFF1F7A4E),
              const Color(0xFF4BAA72),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Image.asset(
                    'assets/icons/final-logo-amplified.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
