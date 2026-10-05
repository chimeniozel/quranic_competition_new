import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:quranic_competition/models/round_result.dart';
import 'package:quranic_competition/core/services/round_results_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
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
  final PermissionService _permissionService = PermissionService();
  final ScrollController _scrollController = ScrollController();

  List<RoundResult> _allResults = []; // Tous les résultats chargés
  List<RoundResult> _results = []; // Résultats filtrés par groupe d'âge
  bool _isLoading = true;
  bool _isPublishing = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Résultats de la recherche : ils viennent directement de la base de
  // données (donc de toute la جولة) et sont chargés page par page.
  List<RoundResult> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchingMore = false;
  bool _searchHasMore = false;
  int _searchPage = 0;
  String _selectedAgeGroup = 'كبار';
  late bool _published;
  bool _isLockedByNextRound = false;
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
    _searchDebounce?.cancel();
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

      final isLocked = await _fetchLockStatus();

      setState(() {
        _allResults = [
          ...(result['results'] as List<RoundResult>),
          ...(resultSmall['results'] as List<RoundResult>),
        ];

        // Filtrer selon le groupe d'âge sélectionné
        _filterResultsByAgeGroup();
        _isLockedByNextRound = isLocked;
      });
    } catch (e) {
      print('Erreur lors du chargement des résultats: $e');
      _showErrorSnackBar('خطأ أثناء تحميل النتائج');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _fetchLockStatus() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('rounds')
          .select('id')
          .eq('version_id', widget.version.id)
          .gt('number', widget.round.number)
          .eq('result_is_published', true);

      return response.isNotEmpty;
    } catch (e) {
      debugPrint('⚠️ Impossible de vérifier le verrouillage de الجولة: $e');
      return false;
    }
  }

  void _filterResultsByAgeGroup() {
    _results =
        _allResults
            .where((result) => result.ageGroup == _selectedAgeGroup)
            .toList();
  }

  void _onScroll() {
    // La liste complète est déjà chargée en entier ; seule la recherche
    // (qui interroge la base) a besoin d'un chargement progressif.
    if (_searchQuery.isEmpty || !_searchHasMore || _isSearchingMore) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreSearchResults();
    }
  }

  /// Lance la recherche directement dans la base de données, sur l'ensemble
  /// des participants de la جولة et non sur les seuls résultats affichés.
  Future<void> _runSearch({bool reset = true}) async {
    final query = _searchQuery;
    if (query.isEmpty) return;

    setState(() {
      if (reset) {
        _isSearching = true;
        _searchPage = 0;
      } else {
        _isSearchingMore = true;
      }
    });

    try {
      final result = await _resultsService.getResultsWithPagination(
        roundId: widget.round.id,
        ageGroup: _selectedAgeGroup,
        page: _searchPage,
        limit: 20,
        searchQuery: query,
        // Cet écran cherche uniquement par numéro d'inscription.
        includeNameInSearch: false,
      );

      if (!mounted || query != _searchQuery) return;

      setState(() {
        final page = result['results'] as List<RoundResult>;
        if (reset) {
          _searchResults = page;
        } else {
          _searchResults.addAll(page);
        }
        _searchHasMore = result['hasMore'] as bool;
        _searchPage = result['currentPage'] as int;
      });
    } catch (e) {
      print('Erreur lors de la recherche des résultats: $e');
      if (mounted && query == _searchQuery) {
        _showErrorSnackBar('خطأ أثناء البحث');
      }
    } finally {
      // Une réponse périmée (l'utilisateur a continué à taper) ne doit pas
      // masquer le chargement de la recherche en cours.
      if (mounted && query == _searchQuery) {
        setState(() {
          _isSearching = false;
          _isSearchingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreSearchResults() async {
    _searchPage++;
    await _runSearch(reset: false);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  Future<void> _publishResults({bool force = false}) async {
    // Vérifier الصلاحيات
    final canPublish = await _permissionService.canPublishContent();
    if (!canPublish) {
      _showErrorSnackBar('ليس لديك صلاحية نشر النتائج');
      return;
    }

    if (_isLockedByNextRound) {
      _showErrorSnackBar(
        'لا يمكن تعديل نتائج هذه الجولة بعد نشر الجولة التالية.',
      );
      return;
    }
    if (_isPublishing) return;
    if (_published && !force) return;
    if (!_hasResults) {
      _showErrorSnackBar('لا توجد نتائج لنشرها');
      return;
    }
    setState(() => _isPublishing = true);
    try {
      final isRepublish = force || _published;

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
                    isRepublish
                        ? 'جاري إعادة نشر النتائج...'
                        : 'جاري نشر النتائج...',
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

      // Activer la prochaine round si elle existe
      try {
        final nextRoundResponse =
            await supabase
                .from('rounds')
                .select('id, is_active')
                .eq('version_id', widget.version.id)
                .eq('number', widget.round.number + 1)
                .maybeSingle();

        if (nextRoundResponse != null) {
          final nextRoundId = nextRoundResponse['id'] as String;
          final nextRoundActive =
              nextRoundResponse['is_active'] as bool? ?? false;

          if (!nextRoundActive) {
            await supabase
                .from('rounds')
                .update({'is_active': true})
                .eq('id', nextRoundId);
          }

          await supabase
              .from('rounds')
              .update({'is_active': false})
              .eq('id', widget.round.id);
        }
      } catch (e) {
        debugPrint('⚠️ Impossible d\'activer la prochaine جولة: $e');
      }

      _isLockedByNextRound = await _fetchLockStatus();

      if (!isRepublish) {
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
        }
      }

      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        setState(() {
          _published = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.public_rounded, color: Colors.white),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  isRepublish
                      ? 'تم إعادة نشر النتائج بنجاح'
                      : 'تم نشر النتائج بنجاح',
                ),
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
    // Vérifier الصلاحيات
    final canPublish = await _permissionService.canPublishContent();
    if (!canPublish) {
      _showErrorSnackBar('ليس لديك صلاحية إلغاء نشر النتائج');
      return;
    }

    if (_isLockedByNextRound) {
      _showErrorSnackBar(
        'لا يمكن تعديل نتائج هذه الجولة بعد نشر الجولة التالية.',
      );
      return;
    }
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
                Icon(Icons.undo_rounded, color: Colors.white),
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

  // Hors recherche : la liste complète déjà chargée. Pendant une recherche :
  // les résultats renvoyés par la base pour toute la جولة.
  List<RoundResult> get _filteredResults =>
      _searchQuery.isEmpty ? _results : _searchResults;

  void _onSearchChanged(String query) {
    final trimmed = query.trim();
    if (trimmed == _searchQuery) return;

    _searchDebounce?.cancel();

    setState(() {
      _searchQuery = trimmed;
      _searchResults = [];
      _searchHasMore = false;
      _searchPage = 0;
      _isSearching = trimmed.isNotEmpty;
    });

    if (trimmed.isEmpty) return;

    // On attend une courte pause de saisie avant d'interroger la base.
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _runSearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'نتائج ${widget.round.name ?? 'الجولة ${widget.round.number}'}',
        ),
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
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      children: [
                        _buildRoundInfo(),
                        const SizedBox(height: AppTheme.spacingL),
                        const EmptyState(
                          icon: Icons.emoji_events_rounded,
                          title: 'لا توجد نتائج متاحة',
                          subtitle: 'لم يتم حساب نتائج هذه الجولة بعد',
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
                        physics: const AlwaysScrollableScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(AppTheme.spacingM),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                _buildRoundInfo(),
                                const SizedBox(height: AppTheme.spacingS),
                                if (_isLockedByNextRound)
                                  _buildLockedNoticeCard(),
                                if (_isLockedByNextRound)
                                  const SizedBox(height: AppTheme.spacingS),
                                _buildAgeGroupSelector(),
                                const SizedBox(height: AppTheme.spacingS),
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
    final round = widget.round;
    final start = round.startDate;

    return AppGradientHeader(
      shape: AppHeaderShape.card,
      compact: true,
      icon: Icons.emoji_events_rounded,
      title: round.name ?? 'الجولة ${round.number}',
      subtitle:
          '${widget.version.name} · ${widget.version.year}'
          '${start != null ? ' · ${start.day}/${start.month}/${start.year}' : ''}',
      trailing: AppHeaderBadge(
        icon: _published ? Icons.public_rounded : Icons.public_off_rounded,
        text: _published ? 'منشور' : 'غير منشور',
      ),
    );
  }

  void _selectAgeGroup(String group) {
    if (group == _selectedAgeGroup) return;
    setState(() => _selectedAgeGroup = group);
    _filterResultsByAgeGroup();
    // La recherche en cours porte sur le groupe d'âge sélectionné.
    if (_searchQuery.isNotEmpty) _runSearch();
  }

  Widget _buildAgeGroupSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'كبار',
          label: Text('الكبار'),
          icon: Icon(Icons.person_rounded),
        ),
        ButtonSegment(
          value: 'صغار',
          label: Text('الصغار'),
          icon: Icon(Icons.child_care_rounded),
        ),
      ],
      selected: {_selectedAgeGroup},
      showSelectedIcon: false,
      onSelectionChanged: (value) => _selectAgeGroup(value.first),
    );
  }

  Widget _buildLockedNoticeCard() {
    return const AppNotice(
      text:
          'لا يمكن تعديل نتائج هذه الجولة: تم نشر نتائج الجولة التالية، '
          'لذلك تم إيقاف النشر أو الإلغاء للحفاظ على التسلسل.',
      color: AppTheme.warningColor,
      icon: Icons.lock_outline_rounded,
    );
  }

  Widget _buildSearchBar() {
    return ModernSearchBar(
      controller: _searchController,
      hintText: 'البحث برقم التسجيل...',
      onChanged: _onSearchChanged,
      onClear: () {
        _searchController.clear();
        _onSearchChanged('');
      },
      margin: EdgeInsets.zero,
    );
  }

  Widget _buildResultsSliver() {
    if (_isSearching) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingXL),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final filteredResults = _filteredResults;

    if (filteredResults.isEmpty) {
      return SliverToBoxAdapter(
        child:
            _searchQuery.isNotEmpty
                ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'لا توجد نتائج',
                  subtitle: 'لم يتم العثور على نتائج تطابق البحث',
                )
                : const EmptyState(
                  icon: Icons.emoji_events_rounded,
                  title: 'لا توجد نتائج لهذه الجولة',
                  subtitle: 'لم يتم العثور على نتائج للجولة المحددة',
                ),
      );
    }

    final showLoadMore = _searchHasMore || _isSearchingMore;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= filteredResults.length) {
            return const Padding(
              padding: EdgeInsets.all(AppTheme.spacingL),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final result = filteredResults[index];
          return _buildResultCard(
            result,
            // Rang réel dans le classement complet (juste également pour un
            // résultat trouvé par la recherche).
            result.rank ?? index + 1,
          );
        }, childCount: filteredResults.length + (showLoadMore ? 1 : 0)),
      ),
    );
  }

  Widget _buildResultCard(RoundResult result, int rank) {
    // Or, argent, bronze pour les trois premiers
    final medalColor = switch (rank) {
      1 => const Color(0xFFD4A84B),
      2 => const Color(0xFF94A3B8),
      3 => const Color(0xFFB45309),
      _ => AppTheme.primaryColor,
    };
    final statusColor =
        result.passed ? AppTheme.successColor : AppTheme.errorColor;

    return AppListCard(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: medalColor.withValues(alpha: rank <= 3 ? 0.15 : 0.08),
          shape: BoxShape.circle,
        ),
        child: Center(
          child:
              rank <= 3
                  ? Icon(
                    Icons.emoji_events_rounded,
                    color: medalColor,
                    size: 22,
                  )
                  : Text(
                    '$rank',
                    style: AppTheme.bodyLarge.copyWith(
                      color: medalColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
        ),
      ),
      title: result.participant.fullName,
      tags: [
        AppTag(
          text: 'رقم ${result.participant.registrationNumber ?? '؟'}',
          color: AppTheme.textSecondaryColor,
          icon: Icons.badge_rounded,
        ),
        AppTag(
          text: result.passed ? 'ناجح' : 'لم ينجح',
          color: statusColor,
          icon:
              result.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
        ),
        if (rank <= 3)
          AppTag(
            text: 'المركز $rank',
            color: medalColor,
            icon: Icons.star_rounded,
          ),
      ],
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            result.score.toStringAsFixed(1),
            style: AppTheme.headingSmall.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text('المعدل', style: AppTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final canPublish = widget.version.isActive && _hasResults;
    final locked = _isPublishing || _isLockedByNextRound;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isExporting ? null : _exportResultsToExcel,
                style: AppButtonStyles.outlined(AppTheme.infoColor),
                icon:
                    _isExporting
                        ? const AppButtonLoader(color: AppTheme.infoColor)
                        : const Icon(Icons.file_download_rounded, size: 18),
                label: const FittedBox(child: Text('تصدير')),
              ),
            ),
            if (canPublish) ...[
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      locked ? null : () => _publishResults(force: _published),
                  style: AppButtonStyles.filled(AppTheme.successColor),
                  icon:
                      _isPublishing
                          ? const AppButtonLoader()
                          : Icon(
                            _published
                                ? Icons.refresh_rounded
                                : Icons.publish_rounded,
                            size: 18,
                          ),
                  label: FittedBox(
                    child: Text(_published ? 'إعادة النشر' : 'نشر النتائج'),
                  ),
                ),
              ),
              if (_published) ...[
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: locked ? null : _unpublishResults,
                    style: AppButtonStyles.outlined(AppTheme.warningColor),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const FittedBox(child: Text('إلغاء النشر')),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
