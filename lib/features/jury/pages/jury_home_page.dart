import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/competition_version.dart';

class JuryHomePage extends StatefulWidget {
  const JuryHomePage({super.key});

  @override
  State<JuryHomePage> createState() => _JuryHomePageState();
}

class _JuryHomePageState extends State<JuryHomePage> {
  AppUser? appUser;
  bool isLoading = true;
  List<CompetitionVersion> _myVersions = [];
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تأكيد تسجيل الخروج'),
          content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await AuthService().signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      // Charger le profil utilisateur
      final user = await AuthService().getUserProfile();

      // Charger les versions assignées au jury
      final versions = await CompetitionVersionService().fetchMyVersions();

      // Charger les statistiques d'évaluation
      Map<String, dynamic> stats = {};
      if (user != null) {
        try {
          // Compter toutes les évaluations du jury
          int totalEvaluations = 0;
          for (final version in versions) {
            final evaluations = await EvaluationService()
                .getEvaluationsByJuryInVersion(
                  juryId: user.id,
                  versionId: version.id,
                );
            totalEvaluations += evaluations.length;
          }

          stats = {
            'total_evaluations': totalEvaluations,
            'completed_versions': versions.where((v) => v.isActive).length,
            'pending_evaluations': 0, // À calculer selon la logique métier
          };
        } catch (e) {
          stats = {
            'total_evaluations': 0,
            'completed_versions': 0,
            'pending_evaluations': 0,
          };
        }
      }

      setState(() {
        appUser = user;
        _myVersions = versions;
        _statistics = stats;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            isLoading
                ? const Text('جارٍ التحميل...')
                : Text('مرحباً ${appUser?.fullName ?? 'عضو لجنة التحكيم'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadData,
          ),
          // Menu profil
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  context.push('/profile');
                  break;
                case 'security':
                  context.push('/security-settings');
                  break;
                case 'logout':
                  _showLogoutConfirmation();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: ListTile(
                      leading: Icon(Icons.person, size: 20),
                      title: Text('الملف الشخصي'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'security',
                    child: ListTile(
                      leading: Icon(Icons.security, size: 20),
                      title: Text('الأمان'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout, size: 20),
                      title: Text('تسجيل الخروج'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.account_circle, size: 24),
            ),
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Carte de bienvenue
                    _buildWelcomeCard(),
                    const SizedBox(height: 20),

                    // Statistiques
                    _buildStatisticsSection(),
                    const SizedBox(height: 20),

                    // Versions assignées
                    _buildVersionsSection(),
                    const SizedBox(height: 20),

                    // Actions rapides
                    _buildQuickActionsSection(),
                  ],
                ),
              ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gavel, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أهلاً وسهلاً',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        appUser?.fullName ?? 'عضو لجنة التحكيم',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'مرحباً بك في لوحة تحكيم مسابقة أهل القرآن',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إحصائيات التقييم',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'إجمالي التقييمات',
                '${_statistics['total_evaluations'] ?? 0}',
                Icons.rate_review,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'النسخ النشطة',
                '${_statistics['completed_versions'] ?? 0}',
                Icons.event,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'النسخ المحكمة من طرفي',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/jury/version_page'),
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              label: const Text('عرض الكل'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_myVersions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد نسخ محكمة حالياً',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ...(_myVersions.take(3).map((version) => _buildVersionCard(version))),
      ],
    );
  }

  Widget _buildVersionCard(CompetitionVersion version) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/jury/version_detail_page', extra: version),
        leading: CircleAvatar(
          backgroundColor: version.isActive ? Colors.green : Colors.grey,
          child: Icon(Icons.event, color: Colors.white),
        ),
        title: Text(
          version.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'السنة: ${version.year}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: Chip(
          label: Text(
            version.isActive ? 'نشطة' : 'منتهية',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: version.isActive ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الإجراءات السريعة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'النسخ المحكمة',
                Icons.event,
                Colors.deepPurple,
                () => context.push('/jury/version_page'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'النتائج',
                Icons.assessment,
                Colors.orange,
                () {
                  // TODO: Implémenter la navigation vers les résultats
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('قريباً...')));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
