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
      })
      ..forward();
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.primaryContainer,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'web/icons/Icon-192.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  AppLocalizations.of(context)?.appTitle ?? 'RC Controller',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context)?.preparingControllerInterface ??
                      'Preparing your controller interface',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
