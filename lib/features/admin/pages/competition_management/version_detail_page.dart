import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/services/participant_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import '../../../../models/competition_version.dart';
import '../../../../models/participant.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:quranic_competition/core/utils/search_utils.dart';

class VersionDetailPage extends StatefulWidget {
  final CompetitionVersion version;

  const VersionDetailPage({super.key, required this.version});

  @override
  State<VersionDetailPage> createState() => _VersionDetailPageState();
}

class _VersionDetailPageState extends State<VersionDetailPage> {
  final ParticipantService _participantService = ParticipantService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Participant> _allParticipants = [];
  List<Participant> _filteredParticipants = [];
  String _selectedGroup = 'كبار';
  String _selectedStatus = 'الكل'; // Nouveau filtre par statut
  bool _isLoading = false;
  int _totalCount = 0;
  String _searchQuery = '';
  AppUser? appUser;
  bool _dataLoaded = false;
  bool _isExporting = false;
  bool _hasError = false;

  // Pagination settings
  static const int _itemsPerPage = 10;
  int _totalPages = 0;
  int _currentPageIndex = 1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadParticipants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants({
    bool reset = true,
    bool forceReload = false,
  }) async {
    // Si les données sont déjà chargées et qu'on ne force pas le rechargement,
    // on applique seulement le filtrage
    if (_dataLoaded && !forceReload) {
      _applyFilter(reset: reset);
      return;
    }

    setState(() {
      _isLoading = _allParticipants.isEmpty;
      _hasError = false;
    });

    try {
      AuthService authService = AuthService();
      AppUser? user = await authService.getUserProfile();

      // Charger tous les participants (acceptés et rejetés) pour la page de détails
      if (reset || forceReload) {
        final participants = await _participantService
            .fetchParticipantsByVersion(
              widget.version.id,
              includeRejected: true, // Inclure les participants rejetés
            );
        if (!mounted) return;
        setState(() {
          appUser = user;
          _allParticipants = participants;
          _dataLoaded = true;
        });
      }

      // Appliquer les filtres et la pagination
      _applyFilter(reset: reset);
    } catch (e) {
      debugPrint('Erreur lors du chargement des participants: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter({bool reset = true}) {
    List<Participant> filtered =
        _allParticipants.where((p) => p.ageGroup == _selectedGroup).toList();

    // Appliquer le filtre par statut
    if (_selectedStatus != 'الكل') {
      filtered =
          filtered.where((p) {
            if (_selectedStatus == 'المقبولون') {
              // Participants acceptés: isAccepted doit être explicitement true
              return p.isAccepted == true;
            } else if (_selectedStatus == 'المرفوضون') {
              // Participants rejetés: isAccepted doit être explicitement false
              // Note: isAccepted est un bool non nullable, donc on vérifie == false
              return p.isAccepted == false;
            }
            return true;
          }).toList();
    }

    // Appliquer la recherche
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.trim();
      final queryLower = query.toLowerCase();
      // Recherche par numéro : numéro d'inscription exact uniquement
      final digits = SearchUtils.numericQuery(query);

      filtered =
          filtered.where((p) {
            if (digits != null) {
              return SearchUtils.numberMatches(p.registrationNumber, digits);
            }
            return p.fullName.toLowerCase().contains(queryLower);
          }).toList();
    }

    // Calculer la pagination
    final totalCount = filtered.length;
    _totalPages = (totalCount / _itemsPerPage).ceil();

    if (reset) {
      _currentPageIndex = 1;
    }

    // S'assurer que la page actuelle ne dépasse pas le nombre total de pages
    if (_currentPageIndex > _totalPages && _totalPages > 0) {
      _currentPageIndex = _totalPages;
    }

    // Appliquer la pagination
    final startIndex = (_currentPageIndex - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalCount);

    final paginatedParticipants =
        totalCount > 0
            ? filtered.sublist(startIndex, endIndex)
            : <Participant>[];

    setState(() {
      _filteredParticipants = paginatedParticipants;
      _totalCount = totalCount;
    });
  }

  void _onSearchChanged() {
    _searchQuery = _searchController.text;
    // Appliquer seulement le filtrage côté client, pas de rechargement serveur
    _applyFilter(reset: true);
  }

  void _selectGroup(String group) {
    if (group != _selectedGroup) {
      setState(() {
        _selectedGroup = group;
      });
      // Appliquer seulement le filtrage côté client, pas de rechargement serveur
      _applyFilter(reset: true);
    }
  }

  void _selectStatus(String status) {
    if (status != _selectedStatus) {
      setState(() {
        _selectedStatus = status;
      });
      // Appliquer seulement le filtrage côté client, pas de rechargement serveur
      _applyFilter(reset: true);
    }
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      setState(() {
        _currentPageIndex = page;
      });
      _applyFilter(reset: false);

      // Scroll vers le haut de la liste
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _goToNextPage() {
    if (_currentPageIndex < _totalPages) {
      _goToPage(_currentPageIndex + 1);
    }
  }

  void _goToPreviousPage() {
    if (_currentPageIndex > 1) {
      _goToPage(_currentPageIndex - 1);
    }
  }

  Future<void> _exportParticipantsToExcel() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      // Préparer les listes selon les filtres demandés
      final List<Participant> accepted =
          _allParticipants.where((p) => p.isAccepted == true).toList();
      final List<Participant> rejected =
          _allParticipants.where((p) => p.isAccepted == false).toList();
      final List<Participant> adults =
          _allParticipants.where((p) => p.ageGroup == 'كبار').toList();
      final List<Participant> children =
          _allParticipants.where((p) => p.ageGroup == 'صغار').toList();

      final xls.Excel excel = xls.Excel.createExcel();

      List<List<xls.CellValue?>> _buildRows(List<Participant> list) {
        final rows = <List<xls.CellValue?>>[];
        rows.add([
          xls.TextCellValue('رقم التسجيل'),
          xls.TextCellValue('الاسم الكامل'),
          xls.TextCellValue('الجنس'),
          xls.TextCellValue('تاريخ الميلاد'),
          xls.TextCellValue('الهاتف'),
          xls.TextCellValue('الفئة'),
          xls.TextCellValue('الحالة'),
          xls.TextCellValue('سبب الرفض'),
          xls.TextCellValue('تاريخ الإنشاء'),
        ]);
        for (final p in list) {
          rows.add([
            xls.TextCellValue((p.registrationNumber ?? '').toString()),
            xls.TextCellValue(p.fullName),
            xls.TextCellValue(p.gender),
            xls.TextCellValue(p.birthDate.toIso8601String().split('T').first),
            xls.TextCellValue(p.phone),
            xls.TextCellValue(p.ageGroup),
            xls.TextCellValue(
              p.isAccepted == true
                  ? 'مقبول'
                  : p.isAccepted == false
                  ? 'مرفوض'
                  : 'قيد المراجعة',
            ),
            xls.TextCellValue(p.rejectionReason ?? ''),
            xls.TextCellValue(p.createdAt.toIso8601String()),
          ]);
        }
        return rows;
      }

      void _addSheet(String name, List<Participant> list) {
        final sheet = excel[name];
        final rows = _buildRows(list);
        for (final row in rows) {
          sheet.appendRow(row);
        }
      }

      // Remplir les feuilles
      _addSheet('جميع المشاركين', _allParticipants);
      _addSheet('المقبولون', accepted);
      _addSheet('المرفوضون', rejected);
      _addSheet('الكبار', adults);
      _addSheet('الصغار', children);

      // Supprimer la feuille par défaut vide (Sheet1)
      try {
        final defaultSheet = excel.getDefaultSheet();
        if (defaultSheet != null) {
          excel.delete(defaultSheet);
        }
      } catch (e) {
        // Si la feuille par défaut n'existe pas ou est déjà supprimée, ignorer
        debugPrint('Note: Impossible de supprimer la feuille par défaut: $e');
      }

      // Nom de fichier significatif بالعربية
      final versionName = widget.version.name.trim();
      final fileName =
          'المتسابقين_المشاركين_في_النسخة_${versionName}_${widget.version.year}.xlsx';

      final bytes = excel.save();
      if (bytes == null) {
        throw Exception('فشل توليد الملف');
      }

      // تحويل List<int> إلى Uint8List للمشاركة والحفظ
      final uint8Bytes = Uint8List.fromList(bytes);

      // حفظ مؤقت للسماح بالمشاركة
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(uint8Bytes, flush: true);

      if (!mounted) return;

      // عرض خيارات للمستخدم: حفظ أو مشاركة
      final action = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('اختر الإجراء', style: AppTheme.headingSmall),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ما الذي تريد فعله بالملف؟', style: AppTheme.bodyMedium),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('save'),
                child: Text(
                  'حفظ في الملفات',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('share'),
                child: Text(
                  'مشاركة',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (action == 'save') {
        // السماح للمستخدم باختيار موقع الحفظ
        try {
          final String? savePath = await FilePicker.platform.saveFile(
            dialogTitle: 'اختر موقع الحفظ',
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
            bytes: uint8Bytes, // مطلوب على Android و iOS
          );

          if (savePath != null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم حفظ الملف بنجاح'),
                backgroundColor: AppTheme.successColor,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          // إذا ألغى المستخدم، لا تفعل شيئاً
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حفظ الملف: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } else if (action == 'share') {
        // مشاركة الملف
        await Share.shareXFiles(
          [XFile(tempFile.path)],
          text:
              'متسابقين النسخة: ${widget.version.name} - سنة ${widget.version.year}',
          subject: 'المتسابقين المشاركين في النسخة ${versionName}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تصدير المشاركين: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _navigateToParticipantDetail(Participant participant) async {
    await context.pushNamed(
      'participant-detail',
      pathParameters: {'participantId': participant.id},
      extra: {'participant': participant, 'version': widget.version},
    );
    // La fiche permet de modifier, accepter, refuser ou supprimer :
    // on recharge la liste au retour pour qu'elle reste à jour
    if (mounted) _loadParticipants(reset: false, forceReload: true);
  }

  Widget _buildParticipantCard(Participant participant) {
    final isAccepted = participant.isAccepted;
    final isMale = participant.gender == 'ذكر';

    return AppListCard(
      onTap: () => _navigateToParticipantDetail(participant),
      highlightColor: isAccepted ? null : AppTheme.errorColor,
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'رقم',
              style: AppTheme.labelSmall.copyWith(color: AppTheme.primaryColor),
            ),
            FittedBox(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  participant.registrationNumber?.toString() ?? '-',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      title: participant.fullName,
      tags: [
        AppTag(
          text: isAccepted ? 'مقبول' : 'مرفوض',
          color: isAccepted ? AppTheme.successColor : AppTheme.errorColor,
          icon: isAccepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
        ),
        AppTag(
          text: isMale ? 'ذكر' : 'أنثى',
          color: isMale ? AppTheme.infoColor : AppTheme.accentColor,
          icon: isMale ? Icons.male_rounded : Icons.female_rounded,
        ),
        if (participant.isEvaluated)
          const AppTag(
            text: 'تم التقييم',
            color: AppTheme.secondaryColor,
            icon: Icons.fact_check_rounded,
          ),
      ],
    );
  }

  int _countFor({String? group, String? status}) {
    return _allParticipants.where((p) {
      if (group != null && p.ageGroup != group) return false;
      if (status == 'المقبولون' && !p.isAccepted) return false;
      if (status == 'المرفوضون' && p.isAccepted) return false;
      return true;
    }).length;
  }

  Widget _buildHeader() {
    final version = widget.version;

    return AppGradientHeader(
      shape: AppHeaderShape.card,
      title: version.name,
      badges: [
        AppHeaderBadge(icon: Icons.calendar_today_rounded, text: 'سنة ${version.year}'),
        AppHeaderBadge(
          icon: version.isActive ? Icons.check_circle_rounded : Icons.history_rounded,
          text: version.isActive ? 'نشطة' : 'منتهية',
        ),
        AppHeaderBadge(
          icon: version.isRegistrationOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
          text: version.isRegistrationOpen ? 'التسجيل مفتوح' : 'التسجيل مغلق',
        ),
      ],
      // Remplissage de chaque فرع par rapport à sa capacité
      bottom: Row(
        children: [
          Expanded(
            child: _buildCapacity(
              'الكبار',
              _countFor(group: 'كبار'),
              version.maxAdults,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: _buildCapacity(
              'الصغار',
              _countFor(group: 'صغار'),
              version.maxChildren,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacity(String label, int count, int max) {
    final ratio = max > 0 ? (count / max).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.labelMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          Text(
            '$count / $max',
            style: AppTheme.headingSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: AppTheme.spacingXS),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return AppSection(
      icon: Icons.filter_list_rounded,
      title: 'تصفية المشاركين',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'كبار',
                label: Text('الكبار (${_countFor(group: 'كبار')})'),
              ),
              ButtonSegment(
                value: 'صغار',
                label: Text('الصغار (${_countFor(group: 'صغار')})'),
              ),
            ],
            selected: {_selectedGroup},
            showSelectedIcon: false,
            onSelectionChanged: (value) => _selectGroup(value.first),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Wrap(
            children: [
              for (final status in const ['الكل', 'المقبولون', 'المرفوضون'])
                chip(
                  '$status (${_countFor(group: _selectedGroup, status: status)})',
                  _selectedStatus == status,
                  () => _selectStatus(status),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          ModernSearchBar(
            controller: _searchController,
            hintText: 'ابحث بالاسم أو رقم التسجيل...',
            margin: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: widget.version.name,
        actions: [
          // Export to Excel
          IconButton(
            onPressed: _isExporting ? null : _exportParticipantsToExcel,
            tooltip: 'تصدير إلى Excel',
            icon:
                _isExporting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.file_download_rounded),
          ),
          IconButton(
            onPressed: () {
              context.pushNamed('admin-version-jurys', extra: widget.version);
            },
            icon: const Icon(Icons.groups_rounded),
            tooltip: 'لجنة التحكيم',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => context.push('/admin/version_results', extra: widget.version),
        icon: const Icon(Icons.analytics_rounded),
        label: const Text('النتائج'),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError && _allParticipants.isEmpty
              ? Center(
                child: SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.wifi_off_rounded,
                    iconColor: AppTheme.errorColor,
                    title: 'تعذر تحميل المشاركين',
                    subtitle: 'تحقق من الاتصال وحاول مجدداً',
                    action: PrimaryButton(
                      text: 'إعادة المحاولة',
                      icon: Icons.refresh_rounded,
                      onPressed: () => _loadParticipants(forceReload: true),
                    ),
                  ),
                ),
              )
              : ModernPullToRefresh(
                onRefresh:
                    () => _loadParticipants(reset: false, forceReload: true),
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingM,
                    AppTheme.spacingM,
                    AppTheme.spacingM,
                    90,
                  ),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: AppTheme.spacingM),
                    _buildFilters(),
                    const SizedBox(height: AppTheme.spacingM),
                    Text(
                      _totalCount > 0
                          ? '$_totalCount مشارك · الصفحة $_currentPageIndex من $_totalPages'
                          : 'لا يوجد مشاركون',
                      style: AppTheme.labelMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    if (_filteredParticipants.isEmpty)
                      EmptyState(
                        icon:
                            _searchQuery.isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.people_outline_rounded,
                        title:
                            _searchQuery.isNotEmpty
                                ? 'لا توجد نتائج للبحث'
                                : 'لا يوجد مشاركون',
                        subtitle:
                            'لا يوجد مشاركون في فرع ${_selectedGroup == 'كبار' ? 'الكبار' : 'الصغار'}'
                            '${_selectedStatus != 'الكل' ? ' - $_selectedStatus' : ''}',
                      )
                    else ...[
                      ..._filteredParticipants.map(_buildParticipantCard),
                      if (_totalPages > 1) _buildPaginationWidget(),
                    ],
                  ],
                ),
              ),
    );
  }

  Widget _buildPaginationWidget() {
    return Container(
      margin: const EdgeInsets.only(top: AppTheme.spacingS),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.shadowS,
      ),
      child: Column(
        children: [
          // Informations de pagination
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الصفحة $_currentPageIndex من $_totalPages',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              Text(
                'إجمالي $_totalCount مشارك',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),

          // Contrôles de pagination
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bouton page précédente
              IconButton(
                onPressed: _currentPageIndex > 1 ? _goToPreviousPage : null,
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color:
                      _currentPageIndex > 1
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                ),
                style: IconButton.styleFrom(
                  backgroundColor:
                      _currentPageIndex > 1
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : AppTheme.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                ),
              ),

              const SizedBox(width: AppTheme.spacingS),

              // Numéros de pages
              Row(children: _buildPageNumbers()),

              const SizedBox(width: AppTheme.spacingS),

              // Bouton page suivante
              IconButton(
                onPressed:
                    _currentPageIndex < _totalPages ? _goToNextPage : null,
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color:
                      _currentPageIndex < _totalPages
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                ),
                style: IconButton.styleFrom(
                  backgroundColor:
                      _currentPageIndex < _totalPages
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : AppTheme.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pageNumbers = [];

    // Calculer la plage de pages à afficher
    int startPage = (_currentPageIndex - 2).clamp(1, _totalPages);
    int endPage = (_currentPageIndex + 2).clamp(1, _totalPages);

    // Ajuster la plage si on est près du début ou de la fin
    if (endPage - startPage < 4) {
      if (startPage == 1) {
        endPage = (startPage + 4).clamp(1, _totalPages);
      } else {
        startPage = (endPage - 4).clamp(1, _totalPages);
      }
    }

    // Ajouter "..." au début si nécessaire
    if (startPage > 1) {
      pageNumbers.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '...',
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
      );
    }

    // Ajouter les numéros de pages
    for (int i = startPage; i <= endPage; i++) {
      final isCurrentPage = i == _currentPageIndex;
      pageNumbers.add(
        GestureDetector(
          onTap: () => _goToPage(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isCurrentPage ? AppTheme.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
              border:
                  isCurrentPage
                      ? null
                      : Border.all(color: AppTheme.dividerColor),
            ),
            child: Text(
              '$i',
              style: AppTheme.labelMedium.copyWith(
                color:
                    isCurrentPage
                        ? AppTheme.surfaceColor
                        : AppTheme.textPrimaryColor,
                fontWeight: isCurrentPage ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    // Ajouter "..." à la fin si nécessaire
    if (endPage < _totalPages) {
      pageNumbers.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '...',
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
      );
    }

    return pageNumbers;
  }
}
