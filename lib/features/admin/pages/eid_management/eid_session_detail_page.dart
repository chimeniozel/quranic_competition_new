import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/eid_session_service.dart';
import 'package:quranic_competition/core/services/push_notification_service.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/utils/search_utils.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/models/eid_participant.dart';
import 'package:quranic_competition/models/eid_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EidSessionDetailPage extends StatefulWidget {
  final EidSession session;

  const EidSessionDetailPage({super.key, required this.session});

  @override
  State<EidSessionDetailPage> createState() => _EidSessionDetailPageState();
}

class _EidSessionDetailPageState extends State<EidSessionDetailPage> {
  /// Nombre maximal de gagnants par قرعة (limite du service)
  static const int _maxWinners = 10;

  final EidSessionService _service = EidSessionService();
  final TextEditingController _searchController = TextEditingController();

  late EidSession _session;
  List<EidParticipant> _participants = [];
  List<EidParticipant> _winners = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  String _searchQuery = '';

  /// La liste des فسحات doit être rechargée au retour
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _service.getAllSessions(),
      _service.getParticipantsBySession(_session.id),
      _service.getWinners(_session.id),
    ]);
    if (!mounted) return;

    final sessions = results[0] as List<EidSession>;
    setState(() {
      _session = sessions.firstWhere(
        (s) => s.id == _session.id,
        orElse: () => _session,
      );
      _participants = results[1] as List<EidParticipant>;
      _winners = results[2] as List<EidParticipant>;
      _isLoading = false;
    });
  }

  void _showMessage(String message, {Color color = AppTheme.successColor}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  /// Les erreurs du service portent déjà un message arabe
  String _errorText(Object e, String fallback) {
    final text = e.toString().replaceFirst('Exception: ', '').trim();
    return RegExp(r'[؀-ۿ]').hasMatch(text) ? text : fallback;
  }

  Future<void> _sendPublicNotification({
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await PushNotificationService().sendNotification(
        title: title,
        body: body,
        type: type,
        payload: jsonEncode({
          ...payload,
          'session_id': _session.id,
          'session_name': _session.name,
          'created_by': Supabase.instance.client.auth.currentUser?.id,
        }),
        userId: null,
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Actions sur la فسحة
  // ---------------------------------------------------------------------------

  Future<void> _editSession() async {
    final result = await context.push(
      '/admin/eid-sessions/${_session.id}/edit',
      extra: _session,
    );
    if (result == true && mounted) {
      _changed = true;
      _loadData();
    }
  }

  Future<void> _setActive(bool value) async {
    setState(() => _isUpdating = true);
    try {
      final updated = await _service.updateSession(
        id: _session.id,
        isActive: value,
      );
      if (!mounted) return;
      setState(() => _session = updated);
      _changed = true;
      _showMessage(value ? 'الفسحة ظاهرة للمشاركين' : 'تم إخفاء الفسحة');
    } catch (e) {
      if (mounted) {
        _showMessage('تعذر تحديث الفسحة', color: AppTheme.errorColor);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _setOpen(bool value) async {
    setState(() => _isUpdating = true);
    try {
      final updated = await _service.updateSession(
        id: _session.id,
        isOpen: value,
      );
      if (!mounted) return;
      setState(() => _session = updated);
      _changed = true;
      _showMessage(value ? 'تم فتح التسجيل' : 'تم إغلاق التسجيل');

      // Notification publique à l'ouverture, si la فسحة est visible
      if (updated.isOpen && updated.isActive) {
        await _sendPublicNotification(
          title: '📝 تم فتح التسجيل',
          body: 'تم فتح التسجيل لفعالية "${updated.name}"',
          type: 'info',
          payload: {'type': 'eid_registration_opened'},
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage('تعذر تحديث حالة التسجيل', color: AppTheme.errorColor);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _deleteSession() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'حذف الفسحة',
      message: 'هل تريد حذف "${_session.name}"؟',
      icon: Icons.delete_forever_rounded,
      color: AppTheme.errorColor,
      confirmText: 'حذف نهائياً',
      warning:
          _participants.isEmpty
              ? null
              : 'تضم هذه الفسحة ${_participants.length} مشارك مسجل. لا يمكن التراجع عن الحذف.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isUpdating = true);
    try {
      await _service.deleteSession(_session.id);
      if (!mounted) return;
      _showMessage('تم حذف الفسحة');
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      _showMessage('تعذر حذف الفسحة', color: AppTheme.errorColor);
    }
  }

  // ---------------------------------------------------------------------------
  // Participants
  // ---------------------------------------------------------------------------

  Future<void> _deleteParticipant(EidParticipant participant) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'حذف المشارك',
      message: 'هل تريد حذف ${participant.fullName} من هذه الفسحة؟',
      icon: Icons.person_remove_rounded,
      color: AppTheme.errorColor,
      confirmText: 'حذف',
    );
    if (!confirmed || !mounted) return;

    try {
      await _service.deleteParticipant(participant.id);
      await _loadData();
      if (mounted) _showMessage('تم حذف المشارك');
    } catch (e) {
      if (mounted) _showMessage('تعذر حذف المشارك', color: AppTheme.errorColor);
    }
  }

  Future<void> _copyPhone(EidParticipant participant) async {
    await Clipboard.setData(ClipboardData(text: participant.phone));
    if (mounted) _showMessage('تم نسخ الرقم', color: AppTheme.infoColor);
  }

  List<EidParticipant> get _filteredParticipants {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _participants;

    // Une saisie numérique cherche le numéro de téléphone exact
    final digits = SearchUtils.numericQuery(query);
    if (digits != null) {
      return _participants
          .where((p) => SearchUtils.numberMatches(p.phone, digits))
          .toList();
    }
    return _participants
        .where((p) => p.fullName.toLowerCase().contains(query))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // قرعة
  // ---------------------------------------------------------------------------

  String? get _lotteryBlocker {
    if (_participants.isEmpty) return 'لا يوجد مشاركون لإجراء القرعة';
    if (!_session.isActive) return 'يجب أن تكون الفسحة ظاهرة لإجراء القرعة';
    if (_session.isOpen) return 'يجب إغلاق التسجيل قبل إجراء القرعة';
    return null;
  }

  Future<void> _startLottery() async {
    final count = await showDialog<int>(
      context: context,
      builder:
          (_) => _LotteryDialog(
            maxWinners: math.min(_maxWinners, _participants.length),
            participantCount: _participants.length,
            replacesWinners: _winners.isNotEmpty,
          ),
    );
    if (count == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const PopScope(
            canPop: false,
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppTheme.spacingM),
                      Text('جاري إجراء القرعة...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    List<EidParticipant>? winners;
    Object? error;
    try {
      winners = await _service.selectWinners(
        sessionId: _session.id,
        numberOfWinners: count,
      );
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // fenêtre de chargement

    if (winners == null) {
      _showMessage(
        _errorText(error!, 'تعذر إجراء القرعة'),
        color: AppTheme.errorColor,
      );
      return;
    }

    _changed = true;
    await _loadData();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => _WinnersDialog(winners: winners!),
    );

    await _sendPublicNotification(
      title: '🏆 تم اختيار الفائزين',
      body: 'تم اختيار الفائزين في فعالية "${_session.name}"',
      type: 'success',
      payload: {
        'type': 'eid_winners_selected',
        'winners_count': winners.length,
      },
    );
  }

  Future<void> _resetWinners() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'إعادة تعيين الفائزين',
      message:
          'سيُلغى اختيار ${_winners.length} فائز، ويمكنك بعدها إجراء قرعة جديدة.',
      icon: Icons.restart_alt_rounded,
      color: AppTheme.warningColor,
      confirmText: 'إعادة التعيين',
    );
    if (!confirmed || !mounted) return;

    try {
      await _service.resetWinners(_session.id);
      await _loadData();
      if (mounted) _showMessage('تمت إعادة تعيين الفائزين');
    } catch (e) {
      if (mounted) {
        _showMessage('تعذر إعادة تعيين الفائزين', color: AppTheme.errorColor);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Widget _buildHeader() {
    final males = _participants.where((p) => p.gender == 'ذكر').length;
    final start = _session.startDate;
    final end = _session.endDate;

    return AppGradientHeader(
      compact: true,
      icon: Icons.celebration_rounded,
      title: _session.name,
      subtitle: _session.description?.trim(),
      badges: [
        AppHeaderBadge(
          icon:
              _session.isActive
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
          text: _session.isActive ? 'ظاهرة' : 'مخفية',
        ),
        AppHeaderBadge(
          icon: _session.isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
          text: _session.isOpen ? 'التسجيل مفتوح' : 'التسجيل مغلق',
          highlightColor: _session.isOpen ? null : AppTheme.secondaryColor,
        ),
        if (start != null || end != null)
          AppHeaderBadge(
            icon: Icons.date_range_rounded,
            text: [
              if (start != null) _formatDate(start),
              if (end != null) _formatDate(end),
            ].join(' - '),
          ),
      ],
      bottom: Row(
        children: [
          Expanded(
            child: AppStatTile(
              label: 'المشاركون',
              value: '${_participants.length}',
              icon: Icons.groups_rounded,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: AppStatTile(
              label: 'ذكور',
              value: '$males',
              icon: Icons.male_rounded,
              color: AppTheme.infoColor,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: AppStatTile(
              label: 'إناث',
              value: '${_participants.length - males}',
              icon: Icons.female_rounded,
              color: AppTheme.accentColor,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: AppStatTile(
              label: 'الفائزون',
              value: '${_winners.length}',
              icon: Icons.emoji_events_rounded,
              color: AppTheme.secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard(EidParticipant participant) {
    final isMale = participant.gender == 'ذكر';
    final color = isMale ? AppTheme.infoColor : AppTheme.accentColor;

    return AppListCard(
      highlightColor: participant.isWinner ? AppTheme.secondaryColor : null,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          isMale ? Icons.male_rounded : Icons.female_rounded,
          color: color,
        ),
      ),
      title: participant.fullName,
      subtitle: '‎${participant.phone}',
      tags: [
        if (participant.isWinner)
          const AppTag(
            text: 'فائز',
            color: AppTheme.secondaryColor,
            icon: Icons.emoji_events_rounded,
          ),
        AppTag(
          text: _formatDate(participant.createdAt),
          color: AppTheme.textSecondaryColor,
          icon: Icons.schedule_rounded,
        ),
      ],
      trailing: PopupMenuButton<String>(
        icon: appMenuIcon,
        tooltip: 'إجراءات',
        onSelected: (action) {
          if (action == 'copy') _copyPhone(participant);
          if (action == 'delete') _deleteParticipant(participant);
        },
        itemBuilder:
            (_) => [
              appMenuItem(
                value: 'copy',
                icon: Icons.copy_rounded,
                label: 'نسخ الرقم',
              ),
              appMenuItem(
                value: 'delete',
                icon: Icons.delete_rounded,
                label: 'حذف',
                color: AppTheme.errorColor,
              ),
            ],
      ),
    );
  }

  Widget _buildParticipantsTab() {
    final participants = _filteredParticipants;

    return ModernPullToRefresh(
      onRefresh: _loadData,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppTheme.spacingM),
        children: [
          if (_participants.isEmpty)
            const EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'لا يوجد مشاركون',
              subtitle: 'لم يسجل أي شخص بعد في هذه الفسحة',
            )
          else ...[
            ModernSearchBar(
              controller: _searchController,
              hintText: 'البحث بالاسم أو رقم الهاتف...',
              margin: EdgeInsets.zero,
              onChanged: (value) => setState(() => _searchQuery = value),
              onClear: () => setState(() => _searchQuery = ''),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              _searchQuery.trim().isEmpty
                  ? '${_participants.length} مشارك'
                  : '${participants.length} من ${_participants.length} مشارك',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            if (participants.isEmpty)
              const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'لا توجد نتائج',
                subtitle: 'لا يوجد مشارك يطابق البحث',
              )
            else
              ...participants.map(_buildParticipantCard),
          ],
        ],
      ),
    );
  }

  Widget _buildLotterySection() {
    final blocker = _lotteryBlocker;

    return AppSection(
      icon: Icons.casino_rounded,
      color: AppTheme.secondaryColor,
      title: 'القرعة',
      subtitle: 'اختيار الفائزين عشوائياً من بين المشاركين',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (blocker != null) ...[
            AppNotice(
              text: blocker,
              color: AppTheme.warningColor,
              icon: Icons.info_rounded,
            ),
            const SizedBox(height: AppTheme.spacingS),
          ],
          ElevatedButton.icon(
            onPressed: blocker == null && !_isUpdating ? _startLottery : null,
            style: AppButtonStyles.filled(AppTheme.secondaryColor),
            icon: const Icon(Icons.casino_rounded),
            label: Text(_winners.isEmpty ? 'إجراء القرعة' : 'قرعة جديدة'),
          ),
          if (_winners.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingS),
            OutlinedButton.icon(
              onPressed: _isUpdating ? null : _resetWinners,
              style: AppButtonStyles.outlined(AppTheme.warningColor),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('إعادة تعيين الفائزين'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWinnerCard(EidParticipant winner, int rank) {
    return AppListCard(
      highlightColor: AppTheme.secondaryColor,
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppTheme.goldColor, AppTheme.secondaryColor],
          ),
        ),
        child: Text(
          '$rank',
          style: AppTheme.headingSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: winner.fullName,
      subtitle: '‎${winner.phone}',
      trailing: IconButton(
        icon: const Icon(Icons.copy_rounded, size: 20),
        tooltip: 'نسخ الرقم',
        color: AppTheme.textSecondaryColor,
        onPressed: () => _copyPhone(winner),
      ),
    );
  }

  Widget _buildWinnersTab() {
    return ModernPullToRefresh(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        children: [
          _buildLotterySection(),
          const SizedBox(height: AppTheme.spacingM),
          if (_winners.isEmpty)
            const EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'لا يوجد فائزون بعد',
              subtitle: 'أغلق التسجيل ثم أجرِ القرعة لاختيار الفائزين',
            )
          else
            for (var i = 0; i < _winners.length; i++)
              _buildWinnerCard(_winners[i], i + 1),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    Widget statusSwitch({
      required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: _isUpdating ? null : onChanged,
        secondary: AppIconBadge(
          icon: icon,
          color: value ? color : AppTheme.textDisabledColor,
        ),
        title: Text(
          title,
          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: AppTheme.bodySmall),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      children: [
        AppSection(
          icon: Icons.tune_rounded,
          title: 'حالة الفسحة',
          trailing:
              _isUpdating
                  ? const AppButtonLoader(color: AppTheme.primaryColor)
                  : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              statusSwitch(
                title: 'ظاهرة للمشاركين',
                subtitle:
                    _session.isActive
                        ? 'تظهر على الصفحة الرئيسية'
                        : 'تفعيلها يخفي الفسحة الظاهرة حالياً',
                icon: Icons.visibility_rounded,
                color: AppTheme.successColor,
                value: _session.isActive,
                onChanged: _setActive,
              ),
              const Divider(height: 1),
              statusSwitch(
                title: 'التسجيل مفتوح',
                subtitle:
                    _session.isOpen
                        ? 'يمكن للمشاركين التسجيل'
                        : 'لا تُقبل تسجيلات جديدة',
                icon: Icons.how_to_reg_rounded,
                color: AppTheme.infoColor,
                value: _session.isOpen,
                onChanged: _setOpen,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        AppSection(
          icon: Icons.edit_note_rounded,
          color: AppTheme.secondaryColor,
          title: 'المعلومات',
          subtitle: 'الاسم والوصف والتواريخ',
          child: OutlinedButton.icon(
            onPressed: _isUpdating ? null : _editSession,
            style: AppButtonStyles.outlined(AppTheme.primaryColor),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('تعديل الفسحة'),
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        AppSection(
          icon: Icons.warning_amber_rounded,
          color: AppTheme.errorColor,
          borderColor: AppTheme.errorColor.withValues(alpha: 0.3),
          title: 'منطقة الخطر',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'حذف الفسحة نهائي ولا يمكن التراجع عنه.',
                style: AppTheme.bodySmall,
              ),
              const SizedBox(height: AppTheme.spacingS),
              OutlinedButton.icon(
                onPressed: _isUpdating ? null : _deleteSession,
                style: AppButtonStyles.outlined(AppTheme.errorColor),
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('حذف الفسحة'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Le retour signale à la liste qu'elle doit se recharger
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: ModernAppBar(
          title: 'تفاصيل الفسحة',
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'تعديل الفسحة',
              onPressed: _isLoading || _isUpdating ? null : _editSession,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
              onPressed: _isLoading ? null : _loadData,
            ),
          ],
        ),
        body:
            _isLoading
                ? const ModernLoadingIndicator(
                  message: 'جاري تحميل البيانات...',
                )
                : DefaultTabController(
                  length: 3,
                  child: NestedScrollView(
                    headerSliverBuilder:
                        (context, _) => [
                          SliverToBoxAdapter(child: _buildHeader()),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _TabBarDelegate(
                              TabBar(
                                labelColor: AppTheme.primaryColor,
                                unselectedLabelColor:
                                    AppTheme.textSecondaryColor,
                                indicatorColor: AppTheme.primaryColor,
                                indicatorWeight: 3,
                                labelStyle: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                tabs: [
                                  Tab(
                                    icon: const Icon(Icons.groups_rounded),
                                    text: 'المشاركون (${_participants.length})',
                                  ),
                                  Tab(
                                    icon: const Icon(
                                      Icons.emoji_events_rounded,
                                    ),
                                    text: 'الفائزون (${_winners.length})',
                                  ),
                                  const Tab(
                                    icon: Icon(Icons.settings_rounded),
                                    text: 'الإعدادات',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                    body: TabBarView(
                      children: [
                        _buildParticipantsTab(),
                        _buildWinnersTab(),
                        _buildSettingsTab(),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}

/// Barre d'onglets épinglée sous l'en-tête
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: AppTheme.backgroundColor,
      elevation: overlapsContent ? 2 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// قرعة : choix du nombre de gagnants, puis résultat
// -----------------------------------------------------------------------------

class _LotteryDialog extends StatefulWidget {
  final int maxWinners;
  final int participantCount;
  final bool replacesWinners;

  const _LotteryDialog({
    required this.maxWinners,
    required this.participantCount,
    required this.replacesWinners,
  });

  @override
  State<_LotteryDialog> createState() => _LotteryDialogState();
}

class _LotteryDialogState extends State<_LotteryDialog> {
  int _count = 1;

  Widget _stepButton(IconData icon, VoidCallback? onPressed) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        foregroundColor: AppTheme.secondaryColor,
        backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.casino_rounded,
                  size: 32,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'إجراء القرعة',
              textAlign: TextAlign.center,
              style: AppTheme.headingSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              'من بين ${widget.participantCount} مشارك',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'عدد الفائزين',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stepButton(
                  Icons.remove_rounded,
                  _count > 1 ? () => setState(() => _count--) : null,
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    '$_count',
                    textAlign: TextAlign.center,
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.secondaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _stepButton(
                  Icons.add_rounded,
                  _count < widget.maxWinners
                      ? () => setState(() => _count++)
                      : null,
                ),
              ],
            ),
            Text(
              'الحد الأقصى: ${widget.maxWinners}',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall,
            ),
            if (widget.replacesWinners) ...[
              const SizedBox(height: AppTheme.spacingM),
              const AppNotice(
                text: 'ستحل نتيجة القرعة الجديدة محل الفائزين الحاليين.',
                color: AppTheme.warningColor,
                icon: Icons.swap_horiz_rounded,
              ),
            ],
            const SizedBox(height: AppTheme.spacingL),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: AppButtonStyles.outlined(
                      AppTheme.textSecondaryColor,
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(_count),
                    style: AppButtonStyles.filled(AppTheme.secondaryColor),
                    icon: const Icon(Icons.casino_rounded, size: 20),
                    label: const Text('ابدأ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WinnersDialog extends StatelessWidget {
  final List<EidParticipant> winners;

  const _WinnersDialog({required this.winners});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 48,
                  color: AppTheme.goldColor,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'مبارك للفائزين',
                  style: AppTheme.headingMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: winners.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final winner = winners[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    winner.fullName,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text('‎${winner.phone}'),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingM,
              0,
              AppTheme.spacingM,
              AppTheme.spacingM,
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: AppButtonStyles.filled(AppTheme.primaryColor),
              child: const Text('تم'),
            ),
          ),
        ],
      ),
    );
  }
}
