import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';

class WaitingVerificationPage extends StatelessWidget {
  const WaitingVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('انتظار التوثيق'),
        leading: TextButton(
          onPressed: () async {
            await AuthService().signOut();
            context.go('/login');
          },
          child: const Icon(Icons.logout_outlined, size: 25),
        ),
      ),
      body: Center(
        child: Text(
          'يرجى انتظار توثيق حسابك من قبل الإدارة',
          style: TextTheme.of(context).titleSmall,
        ),
      ),
    );
  }
}
