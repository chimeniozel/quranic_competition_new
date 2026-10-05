import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/eid_session_service.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/models/eid_session.dart';

class EidSessionsPage extends StatefulWidget {
  const EidSessionsPage({super.key});

  @override
  State<EidSessionsPage> createState() => _EidSessionsPageState();
}

class _EidSessionsPageState extends State<EidSessionsPage> {
  final EidSessionService _service = EidSessionService();
  List<EidSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    // Au rafraîchissement, la liste reste affichée pendant le chargement
    if (_sessions.isEmpty) setState(() => _isLoading = true);
    final sessions = await _service.getAllSessions();
    // La فسحة visible en premier, puis les plus récentes
    sessions.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  Future<void> _createSession() async {
    final result = await context.push('/admin/eid-sessions/create');
    if (result == true) _loadSessions();
  }

  Future<void> _openSession(EidSession session) async {
    final result = await context.push(
      '/admin/eid-sessions/${session.id}',
      extra: session,
    );
    if (result == true) _loadSessions();
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String? _period(EidSession session) {
    final start = session.startDate;
    final end = session.endDate;
    if (start == null && end == null) return null;
    if (start != null && end != null) {
      return '${_formatDate(start)} - ${_formatDate(end)}';
    }
    return start != null
        ? 'من ${_formatDate(start)}'
        : 'إلى ${_formatDate(end!)}';
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    final active = _sessions.where((s) => s.isActive).toList();
    final openCount = _sessions.where((s) => s.isOpen).length;

    return AppGradientHeader(
      icon: Icons.celebration_rounded,
      title: 'فسحة العيد',
      subtitle:
          active.isEmpty
              ? 'لا توجد فسحة ظاهرة للمشاركين حالياً'
              : 'الظاهرة حالياً: ${active.first.name}',
      bottom: Row(
        children: [
          Expanded(
            child: AppStatTile(
              label: 'الكل',
              value: '${_sessions.length}',
              icon: Icons.event_note_rounded,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: AppStatTile(
              label: 'ظاهرة',
              value: '${active.length}',
              icon: Icons.visibility_rounded,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: AppStatTile(
              label: 'تسجيل مفتوح',
              value: '$openCount',
              icon: Icons.how_to_reg_rounded,
              color: AppTheme.infoColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(EidSession session) {
    final color =
        session.isActive ? AppTheme.successColor : AppTheme.textSecondaryColor;
    final period = _period(session);
    final description = session.description?.trim() ?? '';

    return AppListCard(
      onTap: () => _openSession(session),
      highlightColor: session.isActive ? AppTheme.successColor : null,
      leading: AppIconBadge(
        icon: Icons.celebration_rounded,
        color: color,
        size: 24,
      ),
      title: session.name,
      subtitle: description.isEmpty ? null : description,
      tags: [
        AppTag(
          text: session.isActive ? 'ظاهرة للمشاركين' : 'مخفية',
          color: color,
          icon:
              session.isActive
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
        ),
        AppTag(
          text: session.isOpen ? 'التسجيل مفتوح' : 'التسجيل مغلق',
          color: session.isOpen ? AppTheme.infoColor : AppTheme.errorColor,
          icon: session.isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
        ),
        if (period != null)
          AppTag(
            text: period,
            color: AppTheme.secondaryColor,
            icon: Icons.date_range_rounded,
          ),
      ],
    );
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
            onPressed: _isLoading ? null : _loadSessions,
          ),
        ],
      ),
      body:
          _isLoading
              ? const ModernLoadingIndicator(message: 'جاري تحميل الفسحات...')
              : ModernPullToRefresh(
                onRefresh: _loadSessions,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AppNotice(
                            text:
                                'تظهر للمشاركين فسحة واحدة فقط في كل مرة: '
                                'تفعيل فسحة يخفي الفسحة الظاهرة حالياً.',
                            icon: Icons.info_rounded,
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          if (_sessions.isEmpty)
                            const EmptyState(
                              icon: Icons.event_available_rounded,
                              title: 'لا توجد فسحة أو دورة',
                              subtitle:
                                  'أنشئ فسحة جديدة ليتمكن المشاركون من التسجيل',
                            )
                          else
                            ..._sessions.map(_buildSessionCard),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSession,
        icon: const Icon(Icons.add_rounded),
        label: const Text('فسحة جديدة'),
      ),
    );
  }
}
