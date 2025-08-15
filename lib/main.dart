// lib/main.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'screens/dice_roller_screen.dart';
import 'providers/dice_roller_provider.dart';
import 'providers/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await MobileAds.instance.initialize();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => DiceRollerProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// --- FANTASY THEME CONSTANTS ---
const Color kFantasyLightBg = Color(0xFFF5EFE6); // Parchment paper
const Color kFantasyLightPrimary = Color(0xFF8C1D18); // Deep crimson
const Color kFantasyLightAccent = Color(0xFFD4AF37); // Old gold
const Color kFantasyDarkBg = Color(0xFF2C2C2C); // Aged leather / dark stone
const Color kFantasyDarkPrimary = Color(0xFFD4AF37); // Luminous gold
const Color kFantasyDarkAccent = Color(0xFFE57373); // Muted red accent

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    // Define base text themes
    final baseTextTheme = Theme.of(context).textTheme;
    final fantasyTitleTextTheme = GoogleFonts.cinzelTextTheme(baseTextTheme);
    final fantasyBodyTextTheme = GoogleFonts.ebGaramondTextTheme(baseTextTheme);

    // Combine text themes
    final combinedLightTextTheme = fantasyTitleTextTheme.copyWith(
      bodyLarge: fantasyBodyTextTheme.bodyLarge,
      bodyMedium: fantasyBodyTextTheme.bodyMedium,
      bodySmall: fantasyBodyTextTheme.bodySmall,
      labelLarge: fantasyBodyTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.bold, // Make button text bold
        fontSize: 16,
      ),
    );

    final combinedDarkTextTheme = fantasyTitleTextTheme
        .copyWith(
          bodyLarge: fantasyBodyTextTheme.bodyLarge?.copyWith(
            color: kFantasyLightBg,
          ),
          bodyMedium: fantasyBodyTextTheme.bodyMedium?.copyWith(
            color: kFantasyLightBg,
          ),
          bodySmall: fantasyBodyTextTheme.bodySmall?.copyWith(
            color: Colors.grey[400],
          ),
          labelLarge: fantasyBodyTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: kFantasyDarkBg, // Text on golden buttons
          ),
        )
        .apply(displayColor: kFantasyLightBg, bodyColor: kFantasyLightBg);

    return MaterialApp(
      title: 'D&D Dice Roller',
      // --- LIGHT THEME (Parchment & Crimson) ---
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: kFantasyLightPrimary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kFantasyLightPrimary,
          brightness: Brightness.light,
          background: kFantasyLightBg,
          primary: kFantasyLightPrimary,
          secondary: kFantasyLightAccent,
          onPrimary: kFantasyLightBg, // Text on primary color
          onBackground: Colors.brown[900]!, // Text on parchment
        ),
        useMaterial3: true,
        textTheme: combinedLightTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: fantasyTitleTextTheme.headlineSmall?.copyWith(
            color: kFantasyLightPrimary,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: kFantasyLightPrimary),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: kFantasyLightBg.withOpacity(0.7),
          selectedColor: kFantasyLightPrimary,
          labelStyle: TextStyle(color: Colors.brown[900]),
          secondaryLabelStyle: const TextStyle(color: kFantasyLightBg),
          checkmarkColor: kFantasyLightBg,
          side: BorderSide(color: Colors.brown[200]!),
        ),
      ),
      // --- DARK THEME (Ancient Tome & Gold) ---
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: kFantasyDarkPrimary,
        scaffoldBackgroundColor: kFantasyDarkBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kFantasyDarkPrimary,
          brightness: Brightness.dark,
          background: kFantasyDarkBg,
          primary: kFantasyDarkPrimary,
          secondary: kFantasyDarkAccent,
          onPrimary: kFantasyDarkBg, // Text on primary color
          onBackground: kFantasyLightBg, // Text on dark background
        ),
        useMaterial3: true,
        textTheme: combinedDarkTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: fantasyTitleTextTheme.headlineSmall?.copyWith(
            color: kFantasyDarkPrimary,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: kFantasyDarkPrimary),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: kFantasyDarkBg.withOpacity(0.7),
          selectedColor: kFantasyDarkPrimary,
          labelStyle: TextStyle(color: Colors.grey[300]),
          secondaryLabelStyle: const TextStyle(color: kFantasyDarkBg),
          checkmarkColor: kFantasyDarkBg,
          side: BorderSide(color: Colors.grey[700]!),
        ),
      ),
      themeMode: themeProvider.themeMode,
      home: const DiceRollerScreen(),
    );
  }
}
