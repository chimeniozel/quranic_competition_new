import 'package:flutter/material.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:quranic_competition/models/round_result.dart';
import 'package:quranic_competition/core/services/round_results_service.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/core/services/push_notification_service.dart';
import 'dart:convert';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';

class VersionResultPage extends StatefulWidget {
  final CompetitionVersion version;
  final Round round;

  const VersionResultPage({
    super.key,
    required this.version,
    required this.round,
  });

  @override
  State<VersionResultPage> createState() => _VersionResultPageState();
}

class _VersionResultPageState extends State<VersionResultPage> {
  final RoundResultsService _resultsService = RoundResultsService();
  final ScrollController _scrollController = ScrollController();

  List<RoundResult> _allResults = []; // Tous les résultats chargés
  List<RoundResult> _results = []; // Résultats filtrés par groupe d'âge
  bool _isLoading = true;
  bool _isPublishing = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedAgeGroup = 'كبار';
  late bool _published;
  bool get _hasResults => _allResults.isNotEmpty;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _published = widget.round.resultIsPublished;
    _loadResults();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadResults({
    bool reset = true,
    bool isFilterChange = false,
  }) async {
    // Si c'est un changement de filtre, on ne recharge pas depuis le serveur
    if (isFilterChange) {
      _filterResultsByAgeGroup();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Charger tous les résultats (sans filtre par groupe d'âge)
      final result = await _resultsService.getResultsWithPagination(
        roundId: widget.round.id,
        ageGroup: 'كبار', // Charger d'abord les كبار
        page: 0,
        limit: 1000, // Charger plus de résultats d'un coup
      );

      // Charger aussi les صغار si nécessaire
      final resultSmall = await _resultsService.getResultsWithPagination(
        roundId: widget.round.id,
        ageGroup: 'صغار',
        page: 0,
        limit: 1000,
      );

      setState(() {
        _allResults = [
          ...(result['results'] as List<RoundResult>),
          ...(resultSmall['results'] as List<RoundResult>),
        ];

        // Filtrer selon le groupe d'âge sélectionné
        _filterResultsByAgeGroup();
      });
    } catch (e) {
      print('Erreur lors du chargement des résultats: $e');
      _showErrorSnackBar('خطأ أثناء تحميل النتائج');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterResultsByAgeGroup() {
    _results =
        _allResults
            .where((result) => result.ageGroup == _selectedAgeGroup)
            .toList();
  }

  void _onScroll() {
    // Plus besoin de pagination car on charge tous les résultats d'un coup
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  Future<void> _publishResults() async {
    if (_published || _isPublishing) return;
    if (!_hasResults) {
      _showErrorSnackBar('لا توجد نتائج لنشرها');
      return;
    }
    setState(() => _isPublishing = true);
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              backgroundColor: AppTheme.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
              ),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'جاري نشر النتائج...',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
      );

      final supabase = Supabase.instance.client;
      await supabase
          .from('rounds')
          .update({'result_is_published': true})
          .eq('id', widget.round.id);

      // Envoyer une notification publique de publication des résultats
      try {
        final push = PushNotificationService();
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        await push.sendNotification(
          title: '📣 تم نشر نتائج الجولة',
          body:
              'تم نشر نتائج ${widget.round.name ?? 'الجولة ${widget.round.number}'} في نسخة "${widget.version.name}".',
          type: 'info',
          payload: jsonEncode({
            'type': 'results_published',
            'version_id': widget.version.id,
            'version_name': widget.version.name,
            'round_id': widget.round.id,
            'round_name': widget.round.name,
            'round_number': widget.round.number,
            'created_by': currentUserId,
          }),
          userId: null, // à tous les utilisateurs
        );
      } catch (e) {
        // Ne pas bloquer l'UI si la notification échoue
        // print silencieux pour éviter le spam
      }

      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        setState(() {
          _published = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.public, color: Colors.white),
                SizedBox(width: AppTheme.spacingS),
                Text('تم نشر النتائج بنجاح'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showErrorSnackBar('خطأ أثناء نشر النتائج');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _unpublishResults() async {
    if (!_published || _isPublishing) return;
    setState(() => _isPublishing = true);
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              backgroundColor: AppTheme.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
              ),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'جاري إلغاء نشر النتائج...',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
      );

      final supabase = Supabase.instance.client;
      await supabase
          .from('rounds')
          .update({'result_is_published': false})
          .eq('id', widget.round.id);

      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        setState(() => _published = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.undo, color: Colors.white),
                SizedBox(width: AppTheme.spacingS),
                Text('تم إلغاء نشر النتائج'),
              ],
            ),
            backgroundColor: AppTheme.warningColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showErrorSnackBar('خطأ أثناء إلغاء النشر');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _exportResultsToExcel() async {
    if (_isExporting || _allResults.isEmpty) return;
    setState(() => _isExporting = true);

    try {
      // Préparer les listes selon les filtres
      final List<RoundResult> adults =
          _allResults.where((r) => r.ageGroup == 'كبار').toList();
      final List<RoundResult> children =
          _allResults.where((r) => r.ageGroup == 'صغار').toList();
      final List<RoundResult> passed =
          _allResults.where((r) => r.passed).toList();
      final List<RoundResult> failed =
          _allResults.where((r) => !r.passed).toList();

      // Trier par score décroissant (meilleurs résultats en premier)
      adults.sort((a, b) => b.score.compareTo(a.score));
      children.sort((a, b) => b.score.compareTo(a.score));
      passed.sort((a, b) => b.score.compareTo(a.score));
      failed.sort((a, b) => b.score.compareTo(a.score));
      final sortedAllResults = List<RoundResult>.from(_allResults)
        ..sort((a, b) => b.score.compareTo(a.score));

      final xls.Excel excel = xls.Excel.createExcel();

      List<List<xls.CellValue?>> _buildRows(List<RoundResult> list) {
        final rows = <List<xls.CellValue?>>[];
        rows.add([
          xls.TextCellValue('الترتيب'),
          xls.TextCellValue('رقم التسجيل'),
          xls.TextCellValue('الاسم الكامل'),
          xls.TextCellValue('الجنس'),
          xls.TextCellValue('الفئة'),
          xls.TextCellValue('المعدل'),
          xls.TextCellValue('الحالة'),
          xls.TextCellValue('تاريخ النتيجة'),
        ]);
        int rank = 1;
        for (final result in list) {
          rows.add([
            xls.IntCellValue(rank),
            xls.TextCellValue(
              (result.participant.registrationNumber ?? '').toString(),
            ),
            xls.TextCellValue(result.participant.fullName),
            xls.TextCellValue(result.participant.gender),
            xls.TextCellValue(result.ageGroup),
            xls.DoubleCellValue(result.score),
            xls.TextCellValue(result.passed ? 'نجح' : 'لم ينجح'),
            xls.TextCellValue(result.createdAt.toIso8601String()),
          ]);
          rank++;
        }
        return rows;
      }

      void _addSheet(String name, List<RoundResult> list) {
        final sheet = excel[name];
        final rows = _buildRows(list);
        for (final row in rows) {
          sheet.appendRow(row);
        }
      }

      // Remplir les feuilles
      _addSheet('جميع النتائج', sortedAllResults);
      _addSheet('الكبار', adults);
      _addSheet('الصغار', children);
      _addSheet('الناجحون', passed);
      _addSheet('غير الناجحين', failed);

      // Supprimer la feuille par défaut vide (Sheet1)
      try {
        final defaultSheet = excel.getDefaultSheet();
        if (defaultSheet != null) {
          excel.delete(defaultSheet);
        }
      } catch (e) {
        debugPrint('Note: Impossible de supprimer la feuille par défaut: $e');
      }

      // Nom de fichier significatif بالعربية
      final roundName = widget.round.name ?? 'الجولة_${widget.round.number}';
      final versionName = widget.version.name.trim();
      final fileName =
          'نتائج_${roundName}_${versionName}_${widget.version.year}.xlsx';

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
          text: 'نتائج ${roundName} - ${versionName} ${widget.version.year}',
          subject: 'نتائج ${roundName}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تصدير النتائج: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  List<RoundResult> get _filteredResults {
    if (_searchQuery.isEmpty) {
      return _results;
    }
    return _results.where((result) {
      final registrationNumber =
          result.participant.registrationNumber?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return registrationNumber.contains(query);
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'نتائج ${widget.round.name ?? 'الجولة ${widget.round.number}'}',
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [],
      ),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : _results.isEmpty
              ? ModernPullToRefresh(
                onRefresh: () => _loadResults(reset: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: Column(
                      children: [
                        _buildRoundInfo(),
                        const SizedBox(height: AppTheme.spacingXL),
                        ModernCard(
                          child: Container(
                            padding: const EdgeInsets.all(AppTheme.spacingXL),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(
                                    AppTheme.spacingL,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.emoji_events_outlined,
                                    size: 64,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingL),
                                Text(
                                  'لا توجد نتائج متاحة',
                                  style: AppTheme.headingMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingS),
                                Text(
                                  'لم يتم حساب نتائج هذه الجولة بعد',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              : Column(
                children: [
                  Expanded(
                    child: ModernPullToRefresh(
                      onRefresh: () => _loadResults(reset: true),
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                _buildRoundInfo(),
                                const SizedBox(height: AppTheme.spacingS),
                                _buildAgeGroupSelector(),
                                _buildSearchBar(),
                              ]),
                            ),
                          ),
                          _buildResultsSliver(),
                          // Espace en bas pour les boutons
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 80),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Boutons en bas de la page
                  if (_hasResults) _buildBottomActions(),
                ],
              ),
    );
  }

  Widget _buildRoundInfo() {
    return ModernCard(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withOpacity(0.05),
              Colors.transparent,
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.round.name ?? 'الجولة ${widget.round.number}'}',
                    style: AppTheme.headingSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'المسابقة: ${widget.version.name} - ${widget.version.year}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  if (widget.round.startDate != null)
                    Text(
                      'تاريخ البداية: ${widget.round.startDate!.day}/${widget.round.startDate!.month}/${widget.round.startDate!.year}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingS,
                vertical: AppTheme.spacingXS,
              ),
              decoration: BoxDecoration(
                color:
                    _published ? AppTheme.successColor : AppTheme.warningColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Text(
                _published ? 'منشور' : 'غير منشور',
                style: AppTheme.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeGroupSelector() {
    return ModernCard(
      child: Row(
        children: [
          Icon(Icons.groups, color: AppTheme.warningColor, size: 24),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildAgeGroupButton(
                    'كبار',
                    _selectedAgeGroup == 'كبار',
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: _buildAgeGroupButton(
                    'صغار',
                    _selectedAgeGroup == 'صغار',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeGroupButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (label != _selectedAgeGroup) {
          setState(() {
            _selectedAgeGroup = label;
          });
          _filterResultsByAgeGroup();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingS,
          horizontal: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTheme.labelMedium.copyWith(
            color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return ModernCard(
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'البحث برقم التسجيل...',
          hintStyle: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textDisabledColor,
          ),
          prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
          border: InputBorder.none,
          filled: false,
        ),
        style: AppTheme.bodyMedium,
      ),
    );
  }

  Widget _buildResultsSliver() {
    final filteredResults = _filteredResults;

    if (filteredResults.isEmpty) {
      return SliverToBoxAdapter(
        child:
            _searchQuery.isNotEmpty
                ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'لا توجد نتائج',
                  subtitle: 'لم يتم العثور على نتائج تطابق البحث',
                )
                : const EmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: 'لا توجد نتائج لهذه الجولة',
                  subtitle: 'لم يتم العثور على نتائج للجولة المحددة',
                ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final result = filteredResults[index];
          return _buildResultCard(result, index + 1);
        }, childCount: filteredResults.length),
      ),
    );
  }

  Widget _buildResultCard(RoundResult result, int rank) {
    Color medalColor;
    IconData? medalIcon;

    if (rank == 1) {
      medalColor = AppTheme.warningColor;
      medalIcon = Icons.emoji_events;
    } else if (rank == 2) {
      medalColor = AppTheme.textSecondaryColor;
      medalIcon = Icons.emoji_events;
    } else if (rank == 3) {
      medalColor = Colors.brown;
      medalIcon = Icons.emoji_events;
    } else {
      medalColor = AppTheme.primaryColor;
      medalIcon = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ModernCard(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Row(
            children: [
              // Position et médaille
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      rank <= 3
                          ? medalColor.withOpacity(0.1)
                          : AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: rank <= 3 ? medalColor : AppTheme.dividerColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child:
                      medalIcon != null
                          ? Icon(medalIcon, color: medalColor, size: 20)
                          : Text(
                            '$rank',
                            style: AppTheme.labelLarge.copyWith(
                              color: medalColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),

              // Informations du participant
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.participant.fullName,
                      style: AppTheme.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Row(
                      children: [
                        Icon(
                          Icons.badge,
                          color: AppTheme.textSecondaryColor,
                          size: 14,
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          'رقم التسجيل: ${result.participant.registrationNumber ?? '؟'}',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Row(
                      children: [
                        Icon(
                          result.passed ? Icons.check_circle : Icons.cancel,
                          color:
                              result.passed
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                          size: 14,
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          result.passed ? 'نجح' : 'لم ينجح',
                          style: AppTheme.bodySmall.copyWith(
                            color:
                                result.passed
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Score
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingS,
                  vertical: AppTheme.spacingS,
                ),
                decoration: BoxDecoration(
                  color:
                      result.passed
                          ? AppTheme.successColor.withOpacity(0.1)
                          : AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  border: Border.all(
                    color:
                        result.passed
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      result.score.toStringAsFixed(1),
                      style: AppTheme.headingSmall.copyWith(
                        color:
                            result.passed
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'المعدل',
                      style: AppTheme.bodySmall.copyWith(
                        color:
                            result.passed
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
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

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Bouton d'exportation vers Excel
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportResultsToExcel,
                icon:
                    _isExporting
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Icon(Icons.file_download, color: Colors.white),
                label: const Text('تصدير النتائج'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.infoColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingS,
                  ),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  elevation: AppTheme.elevationS,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            // Bouton de publication/dépublication (affiché seulement si la version est active)
            if (widget.version.isActive)
              Expanded(
                child:
                    !_published && _hasResults
                        ? ElevatedButton.icon(
                          onPressed: _isPublishing ? null : _publishResults,
                          icon:
                              _isPublishing
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Icon(
                                    Icons.publish,
                                    color: Colors.white,
                                  ),
                          label: const Text('نشر النتائج'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingS,
                              vertical: AppTheme.spacingS,
                            ),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
                            elevation: AppTheme.elevationS,
                          ),
                        )
                        : _published
                        ? OutlinedButton.icon(
                          onPressed: _isPublishing ? null : _unpublishResults,
                          icon:
                              _isPublishing
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.undo),
                          label: const Text('إلغاء النشر'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.warningColor,
                            side: const BorderSide(
                              color: AppTheme.warningColor,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingS,
                              vertical: AppTheme.spacingS,
                            ),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}
