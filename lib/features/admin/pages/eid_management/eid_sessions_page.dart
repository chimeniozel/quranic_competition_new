import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/eid_session_service.dart';
import 'package:quranic_competition/models/eid_session.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_navigation.dart';
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
            icon: const Icon(Icons.refresh_rounded),
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
                icon: Icons.event_available_rounded,
                title: 'لا توجد فسحة أو دورة',
                subtitle: 'قم بإنشاء فسحة جديدة أو دورة للبدء',
              )
              : ModernPullToRefresh(
                onRefresh: _loadSessions,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingM,
                    AppTheme.spacingM,
                    AppTheme.spacingM,
                    80,
                  ),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return _buildSessionCard(session);
                  },
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/admin/eid-sessions/create');
          if (result == true) _loadSessions();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('فسحة جديدة'),
      ),
    );
  }

  Future<void> _openSession(EidSession session) async {
    final result = await context.push(
      '/admin/eid-sessions/${session.id}',
      extra: session,
    );
    if (result == true) _loadSessions();
  }

  Widget _buildSessionCard(EidSession session) {
    final color =
        session.isActive ? AppTheme.successColor : AppTheme.textSecondaryColor;

    return AppListCard(
      onTap: () => _openSession(session),
      highlightColor: session.isActive ? AppTheme.successColor : null,
      leading: AppIconBadge(icon: Icons.celebration_rounded, color: color, size: 24),
      title: session.name,
      subtitle: session.description,
      tags: [
        AppTag(
          text: session.isActive ? 'ظاهرة للمشاركين' : 'مخفية',
          color: color,
          icon: session.isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
        ),
        AppTag(
          text: session.isOpen ? 'التسجيل مفتوح' : 'التسجيل مغلق',
          color: session.isOpen ? AppTheme.infoColor : AppTheme.errorColor,
          icon: session.isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
        ),
      ],
    );
  }
}
