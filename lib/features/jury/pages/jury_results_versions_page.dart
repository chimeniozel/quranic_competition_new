import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/models/competition_version.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/widgets/modern_navigation.dart';

class JuryResultsVersionsPage extends StatefulWidget {
  const JuryResultsVersionsPage({super.key});

  @override
  State<JuryResultsVersionsPage> createState() =>
      _JuryResultsVersionsPageState();
}

class _JuryResultsVersionsPageState extends State<JuryResultsVersionsPage> {
  final CompetitionVersionService _versionService = CompetitionVersionService();
  bool _isLoading = true;
  List<CompetitionVersion> _versions = [];

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    try {
      final versions = await _versionService.fetchVersions();
      // La version active d'abord, puis les plus récentes
      versions.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return b.year.compareTo(a.year);
      });
      _versions = versions;
    } catch (e) {
      print('Erreur lors du chargement des versions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('خطأ أثناء تحميل النسخ'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'نتائج المسابقة'),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : ModernPullToRefresh(
                onRefresh: _loadVersions,
                child:
                    _versions.isEmpty
                        ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            EmptyState(
                              icon: Icons.event_busy_rounded,
                              title: 'لا توجد نسخ',
                              subtitle: 'لم يتم إنشاء أي نسخة بعد',
                            ),
                          ],
                        )
                        : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          itemCount: _versions.length,
                          itemBuilder:
                              (context, index) =>
                                  _buildVersionCard(_versions[index]),
                        ),
              ),
    );
  }

  Widget _buildVersionCard(CompetitionVersion version) {
    final color =
        version.isActive ? AppTheme.successColor : AppTheme.primaryColor;

    return AppListCard(
      onTap: () => context.push('/jury/results/${version.id}'),
      highlightColor: version.isActive ? AppTheme.successColor : null,
      leading: AppIconBadge(icon: Icons.leaderboard_rounded, color: color, size: 24),
      title: version.name,
      subtitle: 'السنة ${version.year}',
      tags: [
        if (version.isActive)
          const AppTag(
            text: 'نشطة الآن',
            color: AppTheme.successColor,
            icon: Icons.circle_rounded,
          ),
        AppTag(
          text: 'مقاعد الكبار ${version.maxAdults}',
          color: AppTheme.infoColor,
          icon: Icons.groups_rounded,
        ),
        AppTag(
          text: 'مقاعد الصغار ${version.maxChildren}',
          color: AppTheme.warningColor,
          icon: Icons.people_rounded,
        ),
      ],
    );
  }
}
