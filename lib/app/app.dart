import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quranic_competition/core/widgets/auth_initializer.dart';
import 'package:quranic_competition/app/router.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'مسابقة أهل القرآن الواتسابية',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', ''), Locale('en', '')],
      locale: const Locale('ar', ''),
      routerConfig: appRouter,
      builder: (context, child) {
        return AuthInitializer(child: child ?? const SizedBox());
      },
    );
  }
}
