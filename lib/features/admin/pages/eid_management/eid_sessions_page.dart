import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/eid_session_service.dart';
import 'package:quranic_competition/models/eid_session.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/widgets/loading_states.dart';

class EidSessionsPage extends StatefulWidget {
  const EidSessionsPage({super.key});

  @override
  State<EidSessionsPage> createState() => _EidSessionsPageState();
}

class _EidSessionsPageState extends State<EidSessionsPage> {
  final EidSessionService _service = EidSessionService();
  List<EidSession> _sessions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await _service.getAllSessions();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الفسحات أو الدورات: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'فسحة العيد',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadSessions,
          ),
        ],
      ),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : _sessions.isEmpty
              ? EmptyState(
                icon: Icons.event_available,
                title: 'لا توجد فسحة أو دورة',
                subtitle: 'قم بإنشاء فسحة جديدة أو دورة للبدء',
              )
              : ModernPullToRefresh(
                onRefresh: _loadSessions,
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return _buildSessionCard(session);
                  },
                ),
              ),
      floatingActionButton: ModernFAB(
        onPressed: () async {
          final result = await context.push('/admin/eid-sessions/create');
          if (result == true) {
            _loadSessions();
          }
        },
        icon: Icons.add,
        tooltip: 'إضافة فسحة جديدة أو دورة',
      ),
    );
  }

  Widget _buildSessionCard(EidSession session) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: InkWell(
        onTap: () async {
          final result = await context.push(
            '/admin/eid-sessions/${session.id}',
            extra: session,
          );
          if (result == true) {
            _loadSessions();
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.name, style: AppTheme.headingSmall),
                        if (session.description != null) ...[
                          const SizedBox(height: AppTheme.spacingXS),
                          Text(
                            session.description!,
                            style: AppTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                          vertical: AppTheme.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color:
                              session.isActive
                                  ? AppTheme.successColor.withOpacity(0.1)
                                  : AppTheme.textDisabledColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          border: Border.all(
                            color:
                                session.isActive
                                    ? AppTheme.successColor
                                    : AppTheme.textDisabledColor,
                          ),
                        ),
                        child: Text(
                          session.isActive ? 'نشطة' : 'مخفية',
                          style: AppTheme.bodySmall.copyWith(
                            color:
                                session.isActive
                                    ? AppTheme.successColor
                                    : AppTheme.textDisabledColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                          vertical: AppTheme.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color:
                              session.isOpen
                                  ? AppTheme.infoColor.withOpacity(0.1)
                                  : AppTheme.errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          border: Border.all(
                            color:
                                session.isOpen
                                    ? AppTheme.infoColor
                                    : AppTheme.errorColor,
                          ),
                        ),
                        child: Text(
                          session.isOpen ? 'التسجيل مفتوح' : 'التسجيل مغلق',
                          style: AppTheme.bodySmall.copyWith(
                            color:
                                session.isOpen
                                    ? AppTheme.infoColor
                                    : AppTheme.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
