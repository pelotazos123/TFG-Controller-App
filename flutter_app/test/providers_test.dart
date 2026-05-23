import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rccontroller_app/theme_provider.dart';

void main() {
  test('ThemeProvider updates theme mode', () {
    final provider = ThemeProvider();

    expect(provider.themeMode, ThemeMode.system);
    provider.setThemeMode(ThemeMode.dark);
    expect(provider.themeMode, ThemeMode.dark);
    provider.setThemeMode(ThemeMode.light);
    expect(provider.themeMode, ThemeMode.light);
  });

}
