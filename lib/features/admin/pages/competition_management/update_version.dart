import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../../../core/services/competition_version_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../models/competition_version.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/theme/app_theme.dart';

class UpdateVersionPage extends StatefulWidget {
  final CompetitionVersion version;

  const UpdateVersionPage({super.key, required this.version});

  @override
  State<UpdateVersionPage> createState() => _UpdateVersionPageState();
}

class _UpdateVersionPageState extends State<UpdateVersionPage> {
  final _service = CompetitionVersionService();
  final _pushNotificationService = PushNotificationService();
  final _userService = UserService();
  final _permissionService = PermissionService();

  TextEditingController _nameController = TextEditingController();
  TextEditingController _yearController = TextEditingController();
  TextEditingController _maxAdultsController = TextEditingController();
  TextEditingController _maxChildrenController = TextEditingController();
  TextEditingController _successAverageAdultsController =
      TextEditingController();
  TextEditingController _successAverageChildrenController =
      TextEditingController();
  bool _isActive = true;
  bool _isRegistrationOpen = true;
  bool _juryEvaluationEnabled = false;

  // Valeurs précédentes pour détecter les changements
  bool _previousIsRegistrationOpen = false;
  bool _previousJuryEvaluationEnabled = false;

  bool _isLoading = false;
  bool _canEdit = false;
  bool _isCheckingEditability = false;
  bool _areResultsPublished = false;
  bool _isLastVersion = false;
  Map<String, int> _participantCounts = {'adults': 0, 'children': 0};
  bool _canDelete = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    // Initialiser immédiatement avec les données du widget
    _initializeWithWidgetData();
    // Puis charger les données actuelles depuis la base de données
    _loadCurrentVersionData();
    // Vérifier si la version peut être modifiée
    _checkEditability();
    // Vérifier الصلاحيات للحذف
    _checkDeletePermission();
  }

  Future<void> _checkDeletePermission() async {
    final canDelete = await _permissionService.canDelete();
    setState(() {
      _canDelete = canDelete;
    });
  }

  Future<void> _loadCurrentVersionData() async {
    try {
      // Charger les données actuelles depuis la base de données
      final currentVersion = await _service.getVersionById(widget.version.id);
      if (currentVersion != null) {
        // Charger aussi les statistiques des participants
        final participantCounts = await _service.getParticipantCountsByAgeGroup(
          widget.version.id,
        );

        setState(() {
          _nameController.text = currentVersion.name;
          _yearController.text = currentVersion.year.toString();
          _maxAdultsController.text = currentVersion.maxAdults.toString();
          _maxChildrenController.text = currentVersion.maxChildren.toString();
          _successAverageAdultsController.text =
              currentVersion.successAverageAdults.toString();
          _successAverageChildrenController.text =
              currentVersion.successAverageChildren.toString();
          _isActive = currentVersion.isActive;
          // Stocker les valeurs précédentes avant de mettre à jour
          _previousIsRegistrationOpen = _isRegistrationOpen;
          _previousJuryEvaluationEnabled = _juryEvaluationEnabled;
          _isRegistrationOpen = currentVersion.isRegistrationOpen;
          _juryEvaluationEnabled = currentVersion.juryEvaluationEnabled;
          _participantCounts = participantCounts;
        });
      } else {
        // Fallback sur les données du widget si la version n'est pas trouvée
        _initializeWithWidgetData();
      }
    } catch (e) {
      print('Erreur lors du chargement des données de la version: $e');
      // Fallback sur les données du widget en cas d'erreur
      _initializeWithWidgetData();
    }
  }

  void _initializeWithWidgetData() {
    _nameController.text = widget.version.name;
    _yearController.text = widget.version.year.toString();
    _maxAdultsController.text = widget.version.maxAdults.toString();
    _maxChildrenController.text = widget.version.maxChildren.toString();
    _successAverageAdultsController.text =
        widget.version.successAverageAdults.toString();
    _successAverageChildrenController.text =
        widget.version.successAverageChildren.toString();
    _isActive = widget.version.isActive;
    _previousIsRegistrationOpen = widget.version.isRegistrationOpen;
    _previousJuryEvaluationEnabled = widget.version.juryEvaluationEnabled;
    _isRegistrationOpen = widget.version.isRegistrationOpen;
    _juryEvaluationEnabled = widget.version.juryEvaluationEnabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    _maxAdultsController.dispose();
    _maxChildrenController.dispose();
    _successAverageAdultsController.dispose();
    _successAverageChildrenController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      await _loadCurrentVersionData();
      await _checkEditability();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث البيانات'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Vérifie si la version peut être modifiée
  /// Une version peut être modifiée si :
  /// 1. Elle est active, OU
  /// 2. Elle n'est pas active MAIS c'est la dernière version ET les résultats ne sont pas publiés
  Future<void> _checkEditability() async {
    setState(() => _isCheckingEditability = true);
    try {
      // Vérifier si la version est active
      final currentVersion = await _service.getVersionById(widget.version.id);
      if (currentVersion == null) {
        setState(() {
          _canEdit = false;
          _isCheckingEditability = false;
        });
        return;
      }

      if (currentVersion.isActive) {
        // Si la version est active, elle peut toujours être modifiée
        setState(() {
          _canEdit = true;
          _isCheckingEditability = false;
        });
        return;
      }

      // Si la version n'est pas active, vérifier :
      // 1. Si c'est la dernière version (créée la plus récemment)
      // 2. Si les résultats ne sont pas publiés

      // Vérifier si c'est la dernière version
      final allVersions = await _service.fetchVersions();
      if (allVersions.isEmpty) {
        setState(() {
          _canEdit = false;
          _isCheckingEditability = false;
        });
        return;
      }

      // La première version dans la liste triée par created_at décroissant est la dernière
      final lastVersion = allVersions.first;
      _isLastVersion = lastVersion.id == widget.version.id;

      // Vérifier si les résultats sont publiés
      final supabase = Supabase.instance.client;
      final roundsResponse = await supabase
          .from('rounds')
          .select('id, result_is_published')
          .eq('version_id', widget.version.id);

      // Vérifier si au moins un round a des résultats publiés
      _areResultsPublished = roundsResponse.any(
        (round) => round['result_is_published'] == true,
      );

      // La version peut être modifiée si :
      // - Elle est la dernière version ET
      // - Aucun résultat n'est publié
      setState(() {
        _canEdit = _isLastVersion && !_areResultsPublished;
        _isCheckingEditability = false;
      });
    } catch (e) {
      print('❌ Erreur lors de la vérification de la modification: $e');
      setState(() {
        _canEdit = false;
        _isCheckingEditability = false;
      });
    }
  }

  /// Retourne un message expliquant pourquoi la version ne peut pas être modifiée
  String _getEditabilityMessage() {
    final currentVersion = widget.version;

    if (currentVersion.isActive) {
      return 'النسخة نشطة ويمكن تعديلها.';
    }

    if (!_isLastVersion) {
      return 'لا يمكن تعديل النسخة غير النشطة إلا إذا كانت آخر نسخة تم إنشاؤها.';
    }

    if (_areResultsPublished) {
      return 'لا يمكن تعديل النسخة غير النشطة إذا كانت نتائج جولاتها منشورة.';
    }

    return 'لا يمكن تعديل هذه النسخة.';
  }

  /// Envoie une notification à tous les utilisateurs pour l'ouverture de l'inscription
  Future<void> _sendRegistrationOpenedNotification() async {
    try {
      final payload = jsonEncode({
        'type': 'registration_opened',
        'version_id': widget.version.id,
        'version_name': widget.version.name,
      });

      // Envoyer à tous les utilisateurs (user_id = null)
      await _pushNotificationService.sendNotification(
        title: 'تم فتح التسجيل',
        body:
            'تم فتح التسجيل للنسخة "${widget.version.name}". يمكنك الآن التسجيل في النسخة.',
        type: 'info',
        payload: payload,
        userId: null, // null = tous les utilisateurs
      );

      print('✅ Notification d\'ouverture de l\'inscription envoyée');
    } catch (e) {
      print('❌ Erreur lors de l\'envoi de la notification d\'inscription: $e');
      // Ne pas bloquer la mise à jour en cas d'erreur de notification
    }
  }

  /// Envoie une notification à tous les jurys pour l'ouverture de l'évaluation
  Future<void> _sendJuryEvaluationOpenedNotification() async {
    try {
      // Récupérer tous les jurys assignés à cette version
      final jurys = await _userService.getJurysByVersion(widget.version.id);

      if (jurys.isEmpty) {
        print('⚠️ Aucun jury assigné à cette version, aucune notification envoyée');
        return;
      }

      final payload = jsonEncode({
        'type': 'jury_evaluation_opened',
        'version_id': widget.version.id,
        'version_name': widget.version.name,
      });

      // Envoyer une notification à chaque jury
      for (final jury in jurys) {
        try {
          await _pushNotificationService.sendNotification(
            title: 'تم فتح تقييم المحكمين',
            body:
                'تم فتح تقييم المحكمين للنسخة "${widget.version.name}". يمكنك الآن تقييم المشاركين.',
            type: 'info',
            payload: payload,
            userId: jury.id,
          );
        } catch (e) {
          print(
            '❌ Erreur lors de l\'envoi de la notification au jury ${jury.id}: $e',
          );
        }
      }

      print('✅ Notification d\'ouverture de l\'évaluation envoyée à ${jurys.length} jurys');
    } catch (e) {
      print(
        '❌ Erreur lors de l\'envoi de la notification d\'évaluation: $e',
      );
      // Ne pas bloquer la mise à jour en cas d'erreur de notification
    }
  }

  Future<void> _submitUpdate() async {
    // Vérifier الصلاحيات
    final canModify = await _permissionService.canModifyVersions();
    if (!canModify) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ليس لديك صلاحية تعديل النسخ'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    
    // Vérifier si les modifications sont autorisées
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getEditabilityMessage()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final year = int.tryParse(_yearController.text.trim());
    final maxAdults = int.tryParse(_maxAdultsController.text.trim());
    final maxChildren = int.tryParse(_maxChildrenController.text.trim());
    final successAverageAdults = double.tryParse(
      _successAverageAdultsController.text.trim(),
    );
    final successAverageChildren = double.tryParse(
      _successAverageChildrenController.text.trim(),
    );

    if (name.isEmpty ||
        year == null ||
        maxAdults == null ||
        maxChildren == null ||
        successAverageAdults == null ||
        successAverageChildren == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول بشكل صحيح')),
      );
      return;
    }

    // Vérifier que les moyennes sont dans une plage valide (0-100)
    if (successAverageAdults < 0 ||
        successAverageAdults > 100 ||
        successAverageChildren < 0 ||
        successAverageChildren > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن تكون المتوسطات بين 0 و 100')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Détecter les changements avant la mise à jour
      final registrationJustOpened =
          !_previousIsRegistrationOpen && _isRegistrationOpen;
      final juryEvaluationJustOpened =
          !_previousJuryEvaluationEnabled && _juryEvaluationEnabled;

      await _service.updateVersion(
        id: widget.version.id,
        name: name,
        year: year,
        maxAdults: maxAdults,
        maxChildren: maxChildren,
        isActive: _isActive,
        isRegistrationOpen: _isRegistrationOpen,
        juryEvaluationEnabled: _juryEvaluationEnabled,
        successAverageAdults: successAverageAdults,
        successAverageChildren: successAverageChildren,
      );

      // Envoyer les notifications si nécessaire
      if (registrationJustOpened) {
        await _sendRegistrationOpenedNotification();
      }

      if (juryEvaluationJustOpened) {
        await _sendJuryEvaluationOpenedNotification();
      }

      // Mettre à jour les valeurs précédentes après la sauvegarde réussie
      setState(() {
        _previousIsRegistrationOpen = _isRegistrationOpen;
        _previousJuryEvaluationEnabled = _juryEvaluationEnabled;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث النسخة بنجاح')));

      Navigator.of(context).pop(true); // Retour avec succès
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  IconData _getIconForTable(String tableName) {
    switch (tableName) {
      case 'participants':
        return Icons.people;
      case 'rounds':
        return Icons.emoji_events;
      case 'evaluations':
        return Icons.rate_review;
      case 'juryAssignments':
        return Icons.gavel;
      case 'results':
        return Icons.assessment;
      default:
        return Icons.data_object;
    }
  }

  String _getLabelForTable(String tableName) {
    switch (tableName) {
      case 'participants':
        return 'المشاركين';
      case 'rounds':
        return 'الجولات';
      case 'evaluations':
        return 'التقييمات';
      case 'juryAssignments':
        return 'تعيينات المحكمين';
      case 'results':
        return 'النتائج';
      default:
        return tableName;
    }
  }

  Future<void> _showDeleteConfirmation() async {
    try {
      // Vérifier الصلاحيات
      if (!_canDelete) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ليس لديك صلاحية حذف النسخ'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      
      // Vérifier si la compétition est active
      if (_isActive) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكن حذف النسخة النشطة "${widget.version.name}". يجب إلغاء تفعيلها أولاً.',
            ),
            backgroundColor: AppTheme.warningColor,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      // Récupérer les statistiques des éléments liés
      final counts = await _service.getVersionRelatedCounts(widget.version.id);

      // Calculer le total des éléments qui seront supprimés
      final totalElements =
          counts['participants']! +
          counts['rounds']! +
          counts['evaluations']! +
          counts['juryAssignments']! +
          counts['results']!;

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: AppTheme.errorColor, size: 28),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'تأكيد الحذف',
                    style: AppTheme.headingMedium.copyWith(
                      color: AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'هل تريد حذف النسخة "${widget.version.name}"؟',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),

                    // Avertissement sur la suppression en cascade
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: Border.all(
                          color: AppTheme.errorColor.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.errorColor,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Text(
                                'تحذير: هذا الإجراء غير قابل للإلغاء',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.errorColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            'سيتم حذف جميع البيانات المرتبطة بهذه النسخة:',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),

                    // Statistiques des éléments à supprimer
                    if (totalElements > 0) ...[
                      Text(
                        'العناصر التي سيتم حذفها:',
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Liste des statistiques
                      ...counts.entries.map((entry) {
                        if (entry.value > 0) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacingXS,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getIconForTable(entry.key),
                                  size: 16,
                                  color: AppTheme.textSecondaryColor,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Text(
                                  _getLabelForTable(entry.key),
                                  style: AppTheme.bodyMedium,
                                ),
                                const Spacer(),
                                Text(
                                  '${entry.value}',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }).toList(),

                      const SizedBox(height: AppTheme.spacingS),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calculate,
                              size: 16,
                              color: AppTheme.errorColor,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Text(
                              'إجمالي العناصر: ',
                              style: AppTheme.bodyMedium,
                            ),
                            Text(
                              '$totalElements',
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          border: Border.all(
                            color: AppTheme.successColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppTheme.successColor,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Text(
                              'لا توجد بيانات مرتبطة بهذه النسخة',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                SecondaryButton(
                  text: 'إلغاء',
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                PrimaryButton(
                  text: 'حذف نهائياً',
                  onPressed: () => Navigator.of(context).pop(true),
                  backgroundColor: AppTheme.errorColor,
                ),
              ],
            ),
      );

      if (confirmed == true) {
        setState(() => _isDeleting = true);
        try {
          await _service.deleteVersion(widget.version.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تم حذف النسخة "${widget.version.name}" وجميع البيانات المرتبطة بها',
                ),
                backgroundColor: AppTheme.successColor,
                duration: const Duration(seconds: 4),
              ),
            );
            // Retourner à la page précédente avec succès
            Navigator.of(context).pop(true);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل الحذف: $e'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isDeleting = false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل البيانات: $e'),
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
        title: 'تعديل النسخة',
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _refreshData,
            icon: Icon(
              Icons.refresh,
              color:
                  _isLoading
                      ? AppTheme.textSecondaryColor
                      : AppTheme.surfaceColor,
            ),
            tooltip: 'تحديث البيانات',
          ),
          IconButton(
            onPressed: (_isLoading || !_canEdit) ? null : _submitUpdate,
            icon: Icon(
              Icons.save,
              color:
                  (_isLoading || !_canEdit)
                      ? AppTheme.textSecondaryColor
                      : AppTheme.surfaceColor,
            ),
            tooltip: !_canEdit ? 'التعديل غير متاح' : 'حفظ التغييرات',
          ),
        ],
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    children: [
                      // Avertissement si la compétition ne peut pas être modifiée
                      if (_isCheckingEditability)
                        ModernCard(
                          backgroundColor: AppTheme.infoColor.withOpacity(0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.infoColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Expanded(
                                  child: Text(
                                    'جاري التحقق من إمكانية التعديل...',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.infoColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!_isCheckingEditability && !_canEdit)
                        ModernCard(
                          backgroundColor: AppTheme.warningColor.withOpacity(
                            0.1,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_outlined,
                                      color: AppTheme.warningColor,
                                      size: 28,
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Expanded(
                                      child: Text(
                                        'التعديل غير متاح',
                                        style: AppTheme.labelLarge.copyWith(
                                          color: AppTheme.warningColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.spacingS),
                                Text(
                                  _getEditabilityMessage(),
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.warningColor.withOpacity(
                                      0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!_isCheckingEditability && !_canEdit)
                        const SizedBox(height: AppTheme.spacingS),

                      // Header avec informations de la version
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                      Icons.edit,
                                      color: AppTheme.primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'تعديل النسخة',
                                          style: AppTheme.labelLarge.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'تحديث معلومات النسخة الحالية',
                                          style: AppTheme.labelMedium.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Formulaire de base
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المعلومات الأساسية',
                                style: AppTheme.headingMedium,
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              TextField(
                                controller: _nameController,
                                enabled: _canEdit,
                                style: AppTheme.bodyMedium,
                                decoration: InputDecoration(
                                  labelText: 'اسم النسخة',
                                  hintText: 'أدخل اسم النسخة',
                                  prefixIcon: Icon(
                                    Icons.title,
                                    color:
                                        _canEdit
                                            ? AppTheme.primaryColor
                                            : AppTheme.textDisabledColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              TextField(
                                controller: _yearController,
                                enabled: _canEdit,
                                keyboardType: TextInputType.number,
                                style: AppTheme.bodyMedium,
                                decoration: InputDecoration(
                                  labelText: 'السنة',
                                  hintText: 'أدخل السنة',
                                  prefixIcon: Icon(
                                    Icons.calendar_today,
                                    color:
                                        _canEdit
                                            ? AppTheme.primaryColor
                                            : AppTheme.textDisabledColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Limites des participants
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'حدود المشاركين',
                                style: AppTheme.headingMedium,
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _maxAdultsController,
                                      enabled: _canEdit,
                                      keyboardType: TextInputType.number,
                                      style: AppTheme.bodyMedium,
                                      decoration: InputDecoration(
                                        labelText: 'الحد الأقصى للكبار',
                                        hintText: 'عدد الكبار',
                                        prefixIcon: Icon(
                                          Icons.person,
                                          color:
                                              _canEdit
                                                  ? AppTheme.primaryColor
                                                  : AppTheme.textDisabledColor,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusM,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Expanded(
                                    child: TextField(
                                      controller: _maxChildrenController,
                                      enabled: _canEdit,
                                      keyboardType: TextInputType.number,
                                      style: AppTheme.bodyMedium,
                                      decoration: InputDecoration(
                                        labelText: 'الحد الأقصى للصغار',
                                        hintText: 'عدد الصغار',
                                        prefixIcon: Icon(
                                          Icons.person,
                                          color:
                                              _canEdit
                                                  ? AppTheme.secondaryColor
                                                  : AppTheme.textDisabledColor,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusM,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Moyennes de succès
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'متوسطات النجاح',
                                style: AppTheme.headingMedium,
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          _successAverageAdultsController,
                                      enabled: _canEdit,
                                      keyboardType: TextInputType.number,
                                      style: AppTheme.bodyMedium,
                                      decoration: InputDecoration(
                                        labelText: 'متوسط النجاح للكبار (%)',
                                        hintText: '85.0',
                                        prefixIcon: Icon(
                                          Icons.trending_up,
                                          color:
                                              _canEdit
                                                  ? AppTheme.primaryColor
                                                  : AppTheme.textDisabledColor,
                                        ),
                                        suffixText: '%',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusM,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          _successAverageChildrenController,
                                      enabled: _canEdit,
                                      keyboardType: TextInputType.number,
                                      style: AppTheme.bodyMedium,
                                      decoration: InputDecoration(
                                        labelText: 'متوسط النجاح للصغار (%)',
                                        hintText: '14.0',
                                        prefixIcon: Icon(
                                          Icons.trending_up,
                                          color:
                                              _canEdit
                                                  ? AppTheme.secondaryColor
                                                  : AppTheme.textDisabledColor,
                                        ),
                                        suffixText: '%',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusM,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingS,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.infoColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.infoColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppTheme.infoColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Expanded(
                                      child: Text(
                                        'هذه المتوسطات تحدد الحد الأدنى للنجاح في كل جولة. يجب أن تكون بين 0 و 100.',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.infoColor,
                                          fontWeight: FontWeight.w500,
                                        ),
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

                      // Statistiques des participants actuels
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إحصائيات المشاركين الحاليين',
                                style: AppTheme.headingMedium,
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingS,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _participantCounts['adults']! >
                                                    int.tryParse(
                                                      _maxAdultsController.text,
                                                    )!
                                                ? AppTheme.errorColor
                                                    .withOpacity(0.1)
                                                : AppTheme.successColor
                                                    .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusM,
                                        ),
                                        border: Border.all(
                                          color:
                                              _participantCounts['adults']! >
                                                      int.tryParse(
                                                        _maxAdultsController
                                                            .text,
                                                      )!
                                                  ? AppTheme.errorColor
                                                      .withOpacity(0.3)
                                                  : AppTheme.successColor
                                                      .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            color:
                                                _participantCounts['adults']! >
                                                        int.tryParse(
                                                          _maxAdultsController
                                                              .text,
                                                        )!
                                                    ? AppTheme.errorColor
                                                    : AppTheme.successColor,
                                            size: 32,
                                          ),
                                          const SizedBox(
                                            height: AppTheme.spacingS,
                                          ),
                                          Text(
                                            'الكبار',
                                            style: AppTheme.labelMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_participantCounts['adults']} / ${_maxAdultsController.text}',
                                            style: AppTheme.headingSmall.copyWith(
                                              color:
                                                  _participantCounts['adults']! >
                                                          int.tryParse(
                                                            _maxAdultsController
                                                                .text,
                                                          )!
                                                      ? AppTheme.errorColor
                                                      : AppTheme.successColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (_participantCounts['adults']! >
                                              int.tryParse(
                                                _maxAdultsController.text,
                                              )!)
                                            Text(
                                              'تجاوز الحد الأقصى!',
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                    color: AppTheme.errorColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingS,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _participantCounts['children']! >
                                                    int.tryParse(
                                                      _maxChildrenController
                                                          .text,
                                                    )!
                                                ? AppTheme.errorColor
                                                    .withOpacity(0.1)
                                                : AppTheme.successColor
                                                    .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusM,
                                        ),
                                        border: Border.all(
                                          color:
                                              _participantCounts['children']! >
                                                      int.tryParse(
                                                        _maxChildrenController
                                                            .text,
                                                      )!
                                                  ? AppTheme.errorColor
                                                      .withOpacity(0.3)
                                                  : AppTheme.successColor
                                                      .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.child_care,
                                            color:
                                                _participantCounts['children']! >
                                                        int.tryParse(
                                                          _maxChildrenController
                                                              .text,
                                                        )!
                                                    ? AppTheme.errorColor
                                                    : AppTheme.successColor,
                                            size: 32,
                                          ),
                                          const SizedBox(
                                            height: AppTheme.spacingS,
                                          ),
                                          Text(
                                            'الصغار',
                                            style: AppTheme.labelMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_participantCounts['children']} / ${_maxChildrenController.text}',
                                            style: AppTheme.headingSmall.copyWith(
                                              color:
                                                  _participantCounts['children']! >
                                                          int.tryParse(
                                                            _maxChildrenController
                                                                .text,
                                                          )!
                                                      ? AppTheme.errorColor
                                                      : AppTheme.successColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (_participantCounts['children']! >
                                              int.tryParse(
                                                _maxChildrenController.text,
                                              )!)
                                            Text(
                                              'تجاوز الحد الأقصى!',
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                    color: AppTheme.errorColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Paramètres de statut
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إعدادات النسخة',
                                style: AppTheme.headingMedium,
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Message d'information sur la logique des switches
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingS,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.infoColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.infoColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: AppTheme.infoColor,
                                          size: 20,
                                        ),
                                        const SizedBox(
                                          width: AppTheme.spacingS,
                                        ),
                                        Text(
                                          'قواعد الإعدادات',
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: AppTheme.infoColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppTheme.spacingS),
                                    Text(
                                      '• لا يمكن فتح التسجيل وتفعيل تقييم المحكمين في نفس الوقت',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.infoColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '• عند إلغاء تفعيل النسخة، يتم إغلاق التسجيل والتقييم تلقائياً',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.infoColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Statut actif
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingS,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _isActive
                                          ? AppTheme.successColor.withValues(
                                            alpha: 0.1,
                                          )
                                          : AppTheme.errorColor.withValues(
                                            alpha: 0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color:
                                        _isActive
                                            ? AppTheme.successColor.withValues(
                                              alpha: 0.3,
                                            )
                                            : AppTheme.errorColor.withValues(
                                              alpha: 0.3,
                                            ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isActive
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color:
                                          _isActive
                                              ? AppTheme.successColor
                                              : AppTheme.errorColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'النسخة نشطة',
                                            style: AppTheme.bodyLarge.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _isActive
                                                ? 'النسخة متاحة للاستخدام'
                                                : 'النسخة غير متاحة',
                                            style: AppTheme.bodySmall.copyWith(
                                              color:
                                                  AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _isActive,
                                      onChanged:
                                          _canEdit
                                              ? (val) {
                                                setState(() {
                                                  _isActive = val;
                                                  // Si la version est désactivée, fermer l'inscription et l'évaluation
                                                  if (!val) {
                                                    _isRegistrationOpen = false;
                                                    _juryEvaluationEnabled =
                                                        false;
                                                  }
                                                });
                                              }
                                              : null,
                                      activeColor: AppTheme.successColor,
                                      inactiveThumbColor: AppTheme.errorColor,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Statut d'inscription
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingS,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _isRegistrationOpen
                                          ? AppTheme.successColor.withValues(
                                            alpha: 0.1,
                                          )
                                          : AppTheme.errorColor.withValues(
                                            alpha: 0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color:
                                        _isRegistrationOpen
                                            ? AppTheme.successColor.withValues(
                                              alpha: 0.3,
                                            )
                                            : AppTheme.errorColor.withValues(
                                              alpha: 0.3,
                                            ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isRegistrationOpen
                                          ? Icons.lock_open
                                          : Icons.lock,
                                      color:
                                          _isRegistrationOpen
                                              ? AppTheme.successColor
                                              : AppTheme.errorColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'فتح التسجيل',
                                            style: AppTheme.bodyLarge.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _isRegistrationOpen
                                                ? 'التسجيل مفتوح للمشاركين'
                                                : 'التسجيل مغلق',
                                            style: AppTheme.bodySmall.copyWith(
                                              color:
                                                  AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _isRegistrationOpen,
                                      onChanged:
                                          (_canEdit && _isActive)
                                              ? (val) {
                                                setState(() {
                                                  _isRegistrationOpen = val;
                                                  // Si l'inscription est ouverte, désactiver l'évaluation des jurys
                                                  if (val) {
                                                    _juryEvaluationEnabled =
                                                        false;
                                                  }
                                                });
                                              }
                                              : null,
                                      activeColor: AppTheme.successColor,
                                      inactiveThumbColor: AppTheme.errorColor,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Statut d'évaluation des jurys
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingS,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _juryEvaluationEnabled
                                          ? AppTheme.successColor.withValues(
                                            alpha: 0.1,
                                          )
                                          : AppTheme.errorColor.withValues(
                                            alpha: 0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color:
                                        _juryEvaluationEnabled
                                            ? AppTheme.successColor.withValues(
                                              alpha: 0.3,
                                            )
                                            : AppTheme.errorColor.withValues(
                                              alpha: 0.3,
                                            ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _juryEvaluationEnabled
                                          ? Icons.gavel
                                          : Icons.gavel_outlined,
                                      color:
                                          _juryEvaluationEnabled
                                              ? AppTheme.successColor
                                              : AppTheme.errorColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'تفعيل تقييم المحكمين',
                                            style: AppTheme.bodyLarge.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _juryEvaluationEnabled
                                                ? 'المحكمون يمكنهم تقييم المشاركين'
                                                : 'تقييم المحكمين معطل',
                                            style: AppTheme.bodySmall.copyWith(
                                              color:
                                                  AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _juryEvaluationEnabled,
                                      onChanged:
                                          (_canEdit && _isActive)
                                              ? (val) {
                                                setState(() {
                                                  _juryEvaluationEnabled = val;
                                                  // Si l'évaluation des jurys est activée, fermer l'inscription
                                                  if (val) {
                                                    _isRegistrationOpen = false;
                                                  }
                                                });
                                              }
                                              : null,
                                      activeColor: AppTheme.successColor,
                                      inactiveThumbColor: AppTheme.errorColor,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingL),

                      // Bouton de sauvegarde
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          onPressed:
                              (_isLoading || !_canEdit) ? null : _submitUpdate,
                          text:
                              _isLoading
                                  ? 'جاري التحديث...'
                                  : !_canEdit
                                  ? 'التعديل غير متاح'
                                  : 'حفظ التغييرات',
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Bouton de suppression (seulement si non active et avec الصلاحيات)
                      if (!_isActive && _canDelete) ...[
                        SizedBox(
                          width: double.infinity,
                          child: SecondaryButton(
                            onPressed: _isDeleting ? null : () => _showDeleteConfirmation(),
                            text: _isDeleting ? 'جاري الحذف...' : 'حذف النسخة',
                            icon: Icons.delete,
                            borderColor: AppTheme.errorColor,
                            textColor: AppTheme.errorColor,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                      ],
                    ],
                  ),
                ),
              ),
    );
  }
}
