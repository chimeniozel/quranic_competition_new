import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';

class JuryHomePage extends StatelessWidget {
  const JuryHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مرحباً الشيخ'),
        leading: TextButton(
          onPressed: () async {
            await AuthService().signOut();
            context.go('/login');
          },
          child: const Icon(Icons.logout_outlined, size: 25),
        ),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                context.push('/jury/version_page');
              },
              child: Text("النسخ المحكمة من طرفي"),
            ),
          ],
        ),
      ),
    );
  }
}
