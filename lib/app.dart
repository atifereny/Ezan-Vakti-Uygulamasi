import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants/app_colors.dart';
import 'core/app_theme.dart';
import 'presentation/screens/main_screen.dart';

class EzanVaktiApp extends StatelessWidget {
  const EzanVaktiApp({super.key});

  static ThemeData _lightTheme() => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary:                 kPrimary,
      onPrimary:               Colors.white,
      surface:                 kSurface,
      onSurface:               kOnSurface,
      surfaceContainerHighest: Color(0xFFEEE0C4),
      outline:                 kOutline,
      outlineVariant:          Color(0xFFEDD9B0),
    ),
    scaffoldBackgroundColor: kScaffoldBg,
    appBarTheme: const AppBarTheme(
      backgroundColor:        Colors.transparent,
      elevation:              0,
      scrolledUnderElevation: 0,
      foregroundColor:        kOnSurface,
      centerTitle:            true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness:     Brightness.light,
      ),
      titleTextStyle: TextStyle(
        color:      kOnSurface,
        fontSize:   18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: kOnSurface),
    ),
    cardTheme: const CardThemeData(
      color:     kSurface,
      elevation: 0,
      margin:    EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: kOutline),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor:  kSurface,
      indicatorColor:   const Color(0x207A5C2E),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: kPrimary);
        }
        return const IconThemeData(color: kMuted);
      }),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, color: kOnSurface),
      ),
    ),
    dividerTheme: const DividerThemeData(color: kOutline, thickness: 1),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return kPrimary;
        return const Color(0xFFD0BFA0);
      }),
      thumbColor: WidgetStateProperty.all(Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary,
        side: const BorderSide(color: kPrimary),
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: kSurface),
    listTileTheme: const ListTileThemeData(iconColor: kPrimary),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor:  Color(0xFF2C1A08),
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );

  static ThemeData _darkTheme() => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary:                 Color(0xFFC49A5C),
      onPrimary:               Color(0xFF1A0F05),
      surface:                 Color(0xFF2C1A08),
      onSurface:               Color(0xFFF5EDD6),
      surfaceContainerHighest: Color(0xFF3D2810),
      outline:                 Color(0xFF4A3020),
      outlineVariant:          Color(0xFF3A2414),
    ),
    scaffoldBackgroundColor: const Color(0xFF1A0F05),
    appBarTheme: const AppBarTheme(
      backgroundColor:        Colors.transparent,
      elevation:              0,
      scrolledUnderElevation: 0,
      foregroundColor:        Color(0xFFF5EDD6),
      centerTitle:            true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness:     Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        color:      Color(0xFFF5EDD6),
        fontSize:   18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: Color(0xFFF5EDD6)),
    ),
    cardTheme: const CardThemeData(
      color:     Color(0xFF2C1A08),
      elevation: 0,
      margin:    EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: Color(0xFF4A3020)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor:  const Color(0xFF2C1A08),
      indicatorColor:   const Color(0x30C49A5C),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFFC49A5C));
        }
        return const IconThemeData(color: Color(0xFFB8A07A));
      }),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, color: Color(0xFFF5EDD6)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF4A3020), thickness: 1),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const Color(0xFFC49A5C);
        return const Color(0xFF4A3020);
      }),
      thumbColor: WidgetStateProperty.all(const Color(0xFFF5EDD6)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFC49A5C),
        foregroundColor: const Color(0xFF1A0F05),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFC49A5C),
        side: const BorderSide(color: Color(0xFFC49A5C)),
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF2C1A08)),
    listTileTheme: const ListTileThemeData(iconColor: Color(0xFFC49A5C)),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor:  Color(0xFF3D2810),
      contentTextStyle: TextStyle(color: Color(0xFFF5EDD6)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, child) => MaterialApp(
        title:                      'Ezan Vakti',
        debugShowCheckedModeBanner: false,
        theme:     _lightTheme(),
        darkTheme: _darkTheme(),
        themeMode: mode,
        home:      const MainScreen(),
      ),
    );
  }
}
