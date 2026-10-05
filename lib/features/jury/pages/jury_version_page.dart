import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import '../../../core/services/competition_version_service.dart';
import '../../../models/competition_version.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class JuryVersionPage extends StatefulWidget {
  const JuryVersionPage({super.key});

  @override
  State<JuryVersionPage> createState() => _JuryVersionPageState();
}

class _JuryVersionPageState extends State<JuryVersionPage> {
  final _service = CompetitionVersionService();

  List<CompetitionVersion> _versions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = _versions.isEmpty);
    try {
      final versions = await _service.fetchMyVersions();
      // Les versions actives d'abord
      versions.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return b.year.compareTo(a.year);
      });
      if (mounted) setState(() => _versions = versions);
    } catch (e) {
      debugPrint('Erreur lors du chargement des versions du jury: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحميل النسخ. حاول مجدداً.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'النسخ المحكمة من طرفي'),
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
                              icon: Icons.event_available_rounded,
                              title: 'لا توجد نسخ حالياً',
                              subtitle: 'لم يتم تعيين أي نسخ للتحكيم بعد',
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
        version.isActive ? AppTheme.successColor : AppTheme.textSecondaryColor;

    return AppListCard(
      onTap: () => context.push('/jury/version_detail_page', extra: version),
      highlightColor: version.isActive ? AppTheme.successColor : null,
      leading: AppIconBadge(icon: Icons.emoji_events_rounded, color: color, size: 24),
      title: version.name,
      subtitle: 'السنة ${version.year}',
      tags: [
        AppTag(
          text: version.isActive ? 'نشطة' : 'منتهية',
          color: color,
          icon: version.isActive ? Icons.check_circle_rounded : Icons.history_rounded,
        ),
        AppTag(
          text:
              version.juryEvaluationEnabled ? 'التقييم مفتوح' : 'التقييم مغلق',
          color:
              version.juryEvaluationEnabled
                  ? AppTheme.infoColor
                  : AppTheme.textSecondaryColor,
          icon: Icons.gavel_rounded,
        ),
        AppTag(
          text: 'كبار ${version.maxAdults} · صغار ${version.maxChildren}',
          color: AppTheme.secondaryColor,
          icon: Icons.groups_rounded,
        ),
      ],
    );
  }
}
