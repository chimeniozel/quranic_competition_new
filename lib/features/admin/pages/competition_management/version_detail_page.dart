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
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';

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

    if (reset) {
      setState(() => _isLoading = true);
    }

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
        setState(() {
          appUser = user;
          _allParticipants = participants;
          _dataLoaded = true;
        });
      }

      // Appliquer les filtres et la pagination
      _applyFilter(reset: reset);
    } catch (e) {
      print("Erreur lors du chargement des participants: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      final queryDigits = query.replaceAll(RegExp(r'\s+'), '');
      final searchNumber = int.tryParse(queryDigits);

      filtered =
          filtered.where((p) {
            final nameMatches = p.fullName.toLowerCase().contains(queryLower);
            final phoneNormalized = p.phone.replaceAll(RegExp(r'\s+'), '');
            final phoneMatches = phoneNormalized.contains(queryDigits);
            final registrationMatches =
                searchNumber != null && p.registrationNumber == searchNumber;
            return nameMatches || phoneMatches || registrationMatches;
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

  void _navigateToParticipantDetail(Participant participant) {
    context.pushNamed(
      'participant-detail',
      pathParameters: {'participantId': participant.id},
      extra: {'participant': participant, 'version': widget.version},
    );
  }

  Widget _buildParticipantCard(Participant participant) {
    final isAccepted = participant.isAccepted;
    final statusColor =
        isAccepted == true
            ? Colors.green
            : isAccepted == false
            ? Colors.red
            : Colors.orange;

    final statusText =
        isAccepted == true
            ? 'مقبول'
            : isAccepted == false
            ? 'مرفوض'
            : 'قيد المراجعة';

    final statusIcon =
        isAccepted == true
            ? Icons.check_circle
            : isAccepted == false
            ? Icons.cancel
            : Icons.hourglass_empty;

    return ModernCard(
      child: InkWell(
        onTap: () => _navigateToParticipantDetail(participant),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec nom et statut
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Icon(
                      participant.gender == 'ذكر' ? Icons.male : Icons.female,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  // Informations principales
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          participant.fullName,
                          style: AppTheme.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: AppTheme.spacingXS),
                            Text(
                              participant.ageGroup == 'كبار'
                                  ? 'الكبار'
                                  : 'الصغار',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Statut avec icône
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          statusText,
                          style: AppTheme.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),
              // Numéro d'enregistrement
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.confirmation_number,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      'رقم التسجيل: ',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      participant.registrationNumber?.toString() ?? 'غير محدد',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusButton(String status, Color color) {
    final isSelected = _selectedStatus == status;

    return GestureDetector(
      onTap: () => _selectStatus(status),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingS,
          horizontal: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: AppTheme.labelMedium.copyWith(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
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
                    : const Icon(Icons.file_download),
          ),
          IconButton(
            onPressed: () {
              context.pushNamed('admin-version-jurys', extra: widget.version);
            },
            icon: Icon(Icons.groups, color: AppTheme.surfaceColor),
            tooltip: 'لجنة التحكيم',
          ),
        ],
      ),
      floatingActionButton: ModernFAB(
        icon: Icons.analytics,
        onPressed: () async {
          context.push('/admin/version_results', extra: widget.version);
        },
        tooltip: 'النتائج',
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh:
                    () => _loadParticipants(reset: true, forceReload: true),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    children: [
                      // Header avec statistiques
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                        child: Column(
                          children: [
                            Text(
                              widget.version.name,
                              style: AppTheme.headingSmall.copyWith(
                                color: AppTheme.surfaceColor,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'سنة ${widget.version.year}',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.surfaceColor.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                            if (_totalCount > 0) ...[
                              const SizedBox(height: AppTheme.spacingS),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingS,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                ),
                                child: Text(
                                  '${_totalCount} مشارك',
                                  style: AppTheme.labelLarge.copyWith(
                                    color: AppTheme.surfaceColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Statut d'inscription
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingS,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      widget.version.isRegistrationOpen
                                          ? AppTheme.successColor.withValues(
                                            alpha: 0.1,
                                          )
                                          : AppTheme.errorColor.withValues(
                                            alpha: 0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                ),
                                child: Icon(
                                  widget.version.isRegistrationOpen
                                      ? Icons.lock_open
                                      : Icons.lock,
                                  color:
                                      widget.version.isRegistrationOpen
                                          ? AppTheme.successColor
                                          : AppTheme.errorColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'حالة التسجيل',
                                      style: AppTheme.labelMedium.copyWith(
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.version.isRegistrationOpen
                                          ? 'مفتوح'
                                          : 'مغلق',
                                      style: AppTheme.labelLarge.copyWith(
                                        color:
                                            widget.version.isRegistrationOpen
                                                ? AppTheme.successColor
                                                : AppTheme.errorColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Section de filtrage moderne
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.filter_list,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'تصفية المشاركين',
                                    style: AppTheme.labelLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Boutons de catégorie modernisés
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.dividerColor,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _selectGroup('كبار'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: AppTheme.spacingS,
                                            horizontal: AppTheme.spacingL,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                _selectedGroup == 'كبار'
                                                    ? AppTheme.primaryColor
                                                    : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusM,
                                            ),
                                          ),
                                          child: Text(
                                            'كبار',
                                            textAlign: TextAlign.center,
                                            style: AppTheme.labelLarge.copyWith(
                                              color:
                                                  _selectedGroup == 'كبار'
                                                      ? AppTheme.surfaceColor
                                                      : AppTheme
                                                          .textPrimaryColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _selectGroup('صغار'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: AppTheme.spacingS,
                                            horizontal: AppTheme.spacingL,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                _selectedGroup == 'صغار'
                                                    ? AppTheme.secondaryColor
                                                    : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusM,
                                            ),
                                          ),
                                          child: Text(
                                            'صغار',
                                            textAlign: TextAlign.center,
                                            style: AppTheme.labelLarge.copyWith(
                                              color:
                                                  _selectedGroup == 'صغار'
                                                      ? AppTheme.surfaceColor
                                                      : AppTheme
                                                          .textPrimaryColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Filtrage par statut d'acceptation
                              Row(
                                children: [
                                  Icon(
                                    Icons.verified_user,
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'فلترة حسب الحالة',
                                    style: AppTheme.labelLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Boutons de statut
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.dividerColor,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatusButton(
                                        'الكل',
                                        Colors.grey,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildStatusButton(
                                        'المقبولون',
                                        Colors.green,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildStatusButton(
                                        'المرفوضون',
                                        Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Champ de recherche modernisé
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.dividerColor,
                                  ),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.search,
                                  style: AppTheme.bodyMedium,
                                  decoration: InputDecoration(
                                    hintText:
                                        'ابحث بالاسم، رقم الهاتف أو رقم التسجيل...',
                                    hintStyle: AppTheme.labelMedium.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: AppTheme.primaryColor,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacingS,
                                      vertical: AppTheme.spacingS,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Header des participants
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingS,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                ),
                                child: Icon(
                                  Icons.people,
                                  color: AppTheme.primaryColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'المشاركون',
                                      style: AppTheme.labelLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _totalCount > 0
                                          ? 'عرض ${_filteredParticipants.length} من $_totalCount مشارك في فئة ${_selectedGroup}${_selectedStatus != 'الكل' ? ' - ${_selectedStatus}' : ''}'
                                          : 'لا يوجد مشاركون في فئة ${_selectedGroup}${_selectedStatus != 'الكل' ? ' - ${_selectedStatus}' : ''}',
                                      style: AppTheme.labelMedium.copyWith(
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_filteredParticipants.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingS,
                                    vertical: AppTheme.spacingS,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  child: Text(
                                    '${_filteredParticipants.length}',
                                    style: AppTheme.labelLarge.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Liste des participants modernisée
                      if (_filteredParticipants.isEmpty && !_isLoading)
                        EmptyState(
                          icon: Icons.people_outline,
                          title: 'لا يوجد مشاركون',
                          subtitle:
                              'لا يوجد مشاركون في فئة ${_selectedGroup} حالياً',
                        )
                      else
                        Column(
                          children: [
                            // Liste des participants
                            ...List.generate(_filteredParticipants.length, (
                              index,
                            ) {
                              final participant = _filteredParticipants[index];
                              return Container(
                                margin: const EdgeInsets.only(
                                  bottom: AppTheme.spacingS,
                                ),
                                child: _buildParticipantCard(participant),
                              );
                            }),

                            // Widget de pagination moderne
                            if (_totalPages > 1) _buildPaginationWidget(),
                          ],
                        ),
                    ],
                  ),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.dividerColor),
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
                  Icons.chevron_right,
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
                  Icons.chevron_left,
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
