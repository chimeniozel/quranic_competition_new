import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إدارة نسخ المسابقة', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // Naviguer vers صفحة إدارة النسخ
                context.push('/admin/versions');
              },
              icon: const Icon(Icons.list),
              label: const Text('إدارة نسخ المسابقة'),
            ),
            const SizedBox(height: 20),
            // Tu peux ajouter plus de boutons ici, ex: إدارة المستخدمين، لجنة التحكيم...
          ],
        ),
      ),
    );
  }
}
