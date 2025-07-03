import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/models/app_user.dart';

class JuryHomePage extends StatefulWidget {
  const JuryHomePage({super.key});

  @override
  State<JuryHomePage> createState() => _JuryHomePageState();
}

class _JuryHomePageState extends State<JuryHomePage> {
  AppUser? appUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getUserProfile();
  }

  Future<void> getUserProfile() async {
    setState(() => isLoading = true);
    final user = await AuthService().getUserProfile();
    setState(() {
      appUser = user;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isLoading
            ? const Text('جارٍ التحميل...')
            : Text('مرحباً الشيخ ${appUser?.fullName ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await AuthService().signOut();
              context.go('/login');
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      context.push('/jury/version_page');
                    },
                    child: const Text("النسخ المحكمة من طرفي"),
                  ),
                ],
              ),
            ),
    );
  }
}
