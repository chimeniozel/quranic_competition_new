import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/widgets/role_guard.dart';
import 'package:quranic_competition/core/widgets/role_info_widget.dart';
import 'package:quranic_competition/core/services/confirmation_service.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [
          // Badge du rôle de l'utilisateur
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: RoleBadge(),
          ),
          TextButton(
            onPressed: () async {
              final confirmed =
                  await ConfirmationService.showDeleteConfirmation(
                    context,
                    title: 'تأكيد تسجيل الخروج',
                    message: 'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
                    confirmText: 'تسجيل الخروج',
                    cancelText: 'إلغاء',
                    isDestructive: false,
                  );

              if (confirmed) {
                await AuthService().signOut();
                context.go('/login');
              }
            },
            child: const Icon(Icons.logout_outlined, size: 25),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations sur le rôle de l'utilisateur
            const UserProfileRoleInfo(),
            const SizedBox(height: 24),

            // Section gestion des versions (Super Admin et Admin)
            CanCreateVersionsGuard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إدارة نسخ المسابقة',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/admin/versions'),
                    icon: const Icon(Icons.list),
                    label: const Text('إدارة نسخ المسابقة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Section gestion des utilisateurs (Super Admin seulement)
            CanAssignRolesGuard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إدارة المستخدمين والأدوار',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirmed =
                          await ConfirmationService.showCriticalActionConfirmation(
                            context,
                            title: 'إدارة المستخدمين',
                            message:
                                'هذه الصفحة تسمح بتعيين وتعديل أدوار المستخدمين. هل تريد المتابعة؟',
                            actionType: 'إدارة الأدوار',
                          );

                      if (confirmed) {
                        context.push('/admin/users');
                      }
                    },
                    icon: const Icon(Icons.people),
                    label: const Text('إدارة المستخدمين والأدوار'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Section gestion du contenu (Super Admin et Admin)
            CanPublishContentGuard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إدارة المحتوى', style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 12),

                  // Bénéfices coraniques
                  ElevatedButton.icon(
                    onPressed: () => context.push('/admin/quranic-benefits'),
                    icon: const Icon(Icons.menu_book),
                    label: const Text('الفوائد القرآنية'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Règles de Tajweed
                  ElevatedButton.icon(
                    onPressed: () => context.push('/admin/tajweed-rules'),
                    icon: const Icon(Icons.auto_stories),
                    label: const Text('أحكام التجويد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quiz de Tajweed
                  ElevatedButton.icon(
                    onPressed: () => context.push('/admin/quiz/levels'),
                    icon: const Icon(Icons.quiz),
                    label: const Text('مسابقات التجويد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Archives des compétitions
                  ElevatedButton.icon(
                    onPressed: () => context.push('/admin/archives'),
                    icon: const Icon(Icons.archive),
                    label: const Text('أرشيف المسابقات'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Section pour les membres ordinaires
            HasAdminPermissionsGuard(
              fallbackWidget: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey[500]),
                    const SizedBox(height: 16),
                    Text(
                      'عضو عادي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'أنت عضو عادي بدون صلاحيات إدارية.\nيمكنك فقط عرض المحتوى.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
