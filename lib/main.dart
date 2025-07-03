import 'package:flutter/material.dart';
import 'package:quranic_competition/app/router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://slwgmpqpevsodtctpmwz.supabase.co',
    authOptions: FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsd2dtcHFwZXZzb2R0Y3RwbXd6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA0NTYzMjIsImV4cCI6MjA2NjAzMjMyMn0.UpWBLYVgu2-e5I25UTSUewrZiunMTo2xX3Ggb_y4TpI',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'مسابقة أهل القرآن',
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: null, // Ne pas affecter les icônes
        textTheme: ThemeData.light()
            .textTheme
            .apply(fontFamily: "Tajawal"), // Texte en Tajawal
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
    );
  }
}
