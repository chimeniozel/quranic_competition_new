import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
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
  // Empêche d'ouvrir plusieurs dialogues (et d'empiler leurs fonds sombres)
  // en cas d'appuis répétés sur le bouton de suppression.
  bool _isDeleteDialogOpen = false;

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
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث البيانات: $e'),
            backgroundColor: AppTheme.errorColor,
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
        print(
          '⚠️ Aucun jury assigné à cette version, aucune notification envoyée',
        );
        return;
      }

      final payload = jsonEncode({
        'type': 'jury_evaluation_opened',
        'version_id': widget.version.id,
        'version_name': widget.version.name,
      });

      // Envoyer une notification à chaque jury SEULEMENT s'il a vraiment le rôle محكم
      final supabase = Supabase.instance.client;
      for (final jury in jurys) {
        try {
          // Vérifier que le jury a vraiment le rôle محكم avant d'envoyer la notification
          final juryProfile =
              await supabase
                  .from('profiles')
                  .select('role, is_validated')
                  .eq('id', jury.id)
                  .maybeSingle();

          if (juryProfile == null) {
            print('⚠️ Le profil du jury ${jury.fullName} n\'existe pas');
            continue;
          }

          final juryRole = juryProfile['role'] as String? ?? '';
          final isVerified = juryProfile['is_validated'] as bool? ?? false;

          // Vérifier que le rôle est محكم (jury)
          final isJuryRole =
              juryRole.trim().toLowerCase() == 'jury' ||
              juryRole.trim().toLowerCase().contains('jury');

          if (!isJuryRole) {
            print(
              '⚠️ L\'utilisateur ${jury.fullName} n\'a pas le rôle محكم (role: $juryRole). Notification non envoyée.',
            );
            continue;
          }

          if (!isVerified) {
            print(
              '⚠️ L\'utilisateur ${jury.fullName} n\'est pas vérifié. Notification non envoyée.',
            );
            continue;
          }

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

      print(
        '✅ Notification d\'ouverture de l\'évaluation envoyée à ${jurys.length} jurys',
      );
    } catch (e) {
      print('❌ Erreur lors de l\'envoi de la notification d\'évaluation: $e');
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
          backgroundColor: AppTheme.warningColor,
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
        return Icons.people_rounded;
      case 'rounds':
        return Icons.emoji_events_rounded;
      case 'evaluations':
        return Icons.rate_review_rounded;
      case 'juryAssignments':
        return Icons.gavel_rounded;
      case 'results':
        return Icons.assessment_rounded;
      default:
        return Icons.data_object_rounded;
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

  /// Détail des éléments qui seront supprimés avec la version
  Widget _buildDeleteStats(Map<String, int> counts) {
    final totalElements = counts.values.fold<int>(0, (sum, v) => sum + v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (totalElements > 0) ...[
          Text(
            'العناصر التي سيتم حذفها:',
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
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
                Icon(Icons.calculate_rounded, size: 16, color: AppTheme.errorColor),
                const SizedBox(width: AppTheme.spacingS),
                Text('إجمالي العناصر: ', style: AppTheme.bodyMedium),
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
              border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
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
    );
  }

  Future<void> _showDeleteConfirmation() async {
    if (_isDeleteDialogOpen) return;
    _isDeleteDialogOpen = true;
    try {
      await _confirmAndDeleteVersion();
    } finally {
      _isDeleteDialogOpen = false;
    }
  }

  Future<void> _confirmAndDeleteVersion() async {
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

      // Lancer le comptage sans l'attendre : le dialogue s'ouvre tout de
      // suite et affiche les statistiques dès qu'elles arrivent.
      final countsFuture = _service.getVersionRelatedCounts(widget.version.id);

      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_rounded, color: AppTheme.errorColor, size: 28),
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
                                Icons.info_outline_rounded,
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
                    FutureBuilder<Map<String, int>>(
                      future: countsFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(AppTheme.spacingM),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        return _buildDeleteStats(snapshot.data!);
                      },
                    ),
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

  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? suffix,
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      enabled: _canEdit,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      // Rafraîchit le remplissage affiché quand la capacité change
      onChanged: number ? (_) => setState(() {}) : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _buildCapacityTile(String label, int count, String maxText) {
    final max = int.tryParse(maxText.trim()) ?? 0;
    final exceeded = max > 0 && count > max;
    final ratio = max > 0 ? (count / max).clamp(0.0, 1.0) : 0.0;
    final color = exceeded ? AppTheme.errorColor : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.labelMedium),
          Text(
            '$count / ${max > 0 ? max : '-'}',
            style: AppTheme.headingSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
          if (exceeded) ...[
            const SizedBox(height: 4),
            Text(
              'تجاوز الحد الأقصى!',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String onText,
    required String offText,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final color = value ? AppTheme.successColor : AppTheme.textSecondaryColor;

    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingXS,
      ),
      secondary: AppIconBadge(icon: icon, color: color, size: 18),
      title: Text(
        title,
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textPrimaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(value ? onText : offText, style: AppTheme.bodySmall),
      value: value,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final version = widget.version;

    return Scaffold(
      appBar: ModernAppBar(
        title: 'إعدادات النسخة',
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _refreshData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ModernPullToRefresh(
                onRefresh: _refreshData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  children: [
                    // En-tête : version modifiée
                    AppGradientHeader(
                      shape: AppHeaderShape.card,
                      compact: true,
                      icon: Icons.settings_rounded,
                      title: version.name,
                      subtitle: 'سنة ${version.year}',
                      trailing: AppHeaderBadge(
                        icon: _isActive ? Icons.check_circle_rounded : Icons.history_rounded,
                        text: _isActive ? 'نشطة' : 'غير نشطة',
                        highlightColor:
                            _isActive ? AppTheme.secondaryColor : null,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    // Possibilité de modifier
                    if (_isCheckingEditability) ...[
                      const AppNotice(
                        text: 'جاري التحقق من إمكانية التعديل...',
                        icon: Icons.hourglass_top_rounded,
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                    ] else if (!_canEdit) ...[
                      AppNotice(
                        text: 'التعديل غير متاح: ${_getEditabilityMessage()}',
                        color: AppTheme.warningColor,
                        icon: Icons.lock_outline_rounded,
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                    ],

                    AppSection(
                      icon: Icons.info_outline_rounded,
                      title: 'المعلومات الأساسية',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _field(
                            controller: _nameController,
                            label: 'اسم النسخة',
                            hint: 'أدخل اسم النسخة',
                            icon: Icons.title_rounded,
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          _field(
                            controller: _yearController,
                            label: 'السنة',
                            hint: 'أدخل السنة',
                            icon: Icons.calendar_today_rounded,
                            number: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    AppSection(
                      icon: Icons.groups_rounded,
                      color: AppTheme.secondaryColor,
                      title: 'المشاركون',
                      subtitle: 'الحد الأقصى لكل فرع والعدد المسجل حالياً',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  controller: _maxAdultsController,
                                  label: 'الحد الأقصى للكبار',
                                  icon: Icons.person_rounded,
                                  number: true,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: _field(
                                  controller: _maxChildrenController,
                                  label: 'الحد الأقصى للصغار',
                                  icon: Icons.child_care_rounded,
                                  number: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCapacityTile(
                                  'الكبار',
                                  _participantCounts['adults'] ?? 0,
                                  _maxAdultsController.text,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: _buildCapacityTile(
                                  'الصغار',
                                  _participantCounts['children'] ?? 0,
                                  _maxChildrenController.text,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    AppSection(
                      icon: Icons.trending_up_rounded,
                      color: AppTheme.successColor,
                      title: 'متوسطات النجاح',
                      subtitle: 'الحد الأدنى للنجاح في كل جولة (بين 0 و 100)',
                      child: Row(
                        children: [
                          Expanded(
                            child: _field(
                              controller: _successAverageAdultsController,
                              label: 'الكبار',
                              hint: '85.0',
                              suffix: '%',
                              icon: Icons.person_rounded,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: _field(
                              controller: _successAverageChildrenController,
                              label: 'الصغار',
                              hint: '14.0',
                              suffix: '%',
                              icon: Icons.child_care_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    AppSection(
                      icon: Icons.tune_rounded,
                      color: AppTheme.infoColor,
                      title: 'حالة النسخة',
                      child: Column(
                        children: [
                          const AppNotice(
                            text:
                                'لا يمكن فتح التسجيل وتفعيل تقييم المحكمين في نفس الوقت. '
                                'عند إلغاء تفعيل النسخة يُغلق التسجيل والتقييم تلقائياً.',
                          ),
                          const SizedBox(height: AppTheme.spacingXS),
                          _switchTile(
                            icon: Icons.power_settings_new_rounded,
                            title: 'النسخة نشطة',
                            onText: 'النسخة متاحة للاستخدام',
                            offText: 'النسخة غير متاحة',
                            value: _isActive,
                            onChanged:
                                _canEdit
                                    ? (val) => setState(() {
                                      _isActive = val;
                                      // Désactivée : inscription et évaluation fermées
                                      if (!val) {
                                        _isRegistrationOpen = false;
                                        _juryEvaluationEnabled = false;
                                      }
                                    })
                                    : null,
                          ),
                          const Divider(),
                          _switchTile(
                            icon: Icons.how_to_reg_rounded,
                            title: 'فتح التسجيل',
                            onText: 'التسجيل مفتوح للمشاركين',
                            offText: 'التسجيل مغلق',
                            value: _isRegistrationOpen,
                            onChanged:
                                (_canEdit && _isActive)
                                    ? (val) => setState(() {
                                      _isRegistrationOpen = val;
                                      // Inscription ouverte : évaluation désactivée
                                      if (val) _juryEvaluationEnabled = false;
                                    })
                                    : null,
                          ),
                          const Divider(),
                          _switchTile(
                            icon: Icons.gavel_rounded,
                            title: 'تقييم المحكمين',
                            onText: 'المحكمون يمكنهم تقييم المشاركين',
                            offText: 'تقييم المحكمين معطل',
                            value: _juryEvaluationEnabled,
                            onChanged:
                                (_canEdit && _isActive)
                                    ? (val) => setState(() {
                                      _juryEvaluationEnabled = val;
                                      // Évaluation activée : inscription fermée
                                      if (val) _isRegistrationOpen = false;
                                    })
                                    : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    ElevatedButton.icon(
                      onPressed:
                          (_isLoading || !_canEdit) ? null : _submitUpdate,
                      style: AppButtonStyles.filled(AppTheme.primaryColor),
                      icon: const Icon(Icons.save_rounded),
                      label: Text(
                        !_canEdit ? 'التعديل غير متاح' : 'حفظ التغييرات',
                      ),
                    ),

                    // Suppression : seulement si non active et avec la صلاحية
                    if (!_isActive && _canDelete) ...[
                      const SizedBox(height: AppTheme.spacingM),
                      AppSection(
                        icon: Icons.warning_amber_rounded,
                        color: AppTheme.errorColor,
                        title: 'منطقة الخطر',
                        subtitle:
                            'حذف النسخة يحذف جميع المشاركين والجولات والنتائج',
                        borderColor: AppTheme.errorColor,
                        child: OutlinedButton.icon(
                          onPressed:
                              _isDeleting ? null : _showDeleteConfirmation,
                          style: AppButtonStyles.outlined(AppTheme.errorColor),
                          icon:
                              _isDeleting
                                  ? const AppButtonLoader(
                                    color: AppTheme.errorColor,
                                  )
                                  : const Icon(Icons.delete_forever_rounded),
                          label: Text(
                            _isDeleting ? 'جاري الحذف...' : 'حذف النسخة',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacingL),
                  ],
                ),
              ),
    );
  }
}
