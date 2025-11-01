import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/participant_service.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/models/participant.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';

class ParticipantRegisterPage extends StatefulWidget {
  final String versionId;
  final String ageGroup;
  const ParticipantRegisterPage({
    super.key,
    required this.versionId,
    required this.ageGroup,
  });

  @override
  State<ParticipantRegisterPage> createState() =>
      _ParticipantRegisterPageState();
}

class _ParticipantRegisterPageState extends State<ParticipantRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = ParticipantService();
  final _competitionService = CompetitionVersionService();

  // Controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();

  String? _quranMemorized;
  String? _readingMethods;
  String? _gender;
  String? _residence;

  bool _hasIjaza = false;
  bool _wonPreviousRanks = false;
  bool _participatedBefore = false;
  DateTime? _selectedBirthDate;
  bool _isLoading = false;
  bool _isRegistrationAllowed = false;
  String? _registrationErrorMessage;
  StreamSubscription<Map<String, dynamic>>? _versionSubscription;

  @override
  void initState() {
    super.initState();
    _startListeningToVersionChanges();
  }

  @override
  void dispose() {
    _versionSubscription?.cancel();
    super.dispose();
  }

  void _startListeningToVersionChanges() {
    print(
      '🔍 Début de l\'écoute des changements pour la version: ${widget.versionId}',
    );

    _versionSubscription = _competitionService
        .listenToVersionChanges(widget.versionId)
        .listen(
          (versionData) {
            print('📡 Données reçues: $versionData');

            if (mounted && versionData.isNotEmpty) {
              final bool isActive = versionData['is_active'] as bool? ?? false;
              final bool isRegistrationOpen =
                  versionData['is_registration_open'] as bool? ?? false;

              print(
                '📊 État actuel: isActive=$isActive, isRegistrationOpen=$isRegistrationOpen',
              );

              final bool wasAllowed = _isRegistrationAllowed;
              final bool nowAllowed = isActive && isRegistrationOpen;

              print('🔄 Changement d\'état: $wasAllowed -> $nowAllowed');

              setState(() {
                _isRegistrationAllowed = nowAllowed;
                if (!_isRegistrationAllowed) {
                  if (!isActive) {
                    _registrationErrorMessage = 'المسابقة غير نشطة';
                  } else if (!isRegistrationOpen) {
                    _registrationErrorMessage = 'التسجيل مغلق لهذه المسابقة';
                  }
                } else {
                  _registrationErrorMessage = null;
                }
              });

              // Notifier l'utilisateur du changement d'état
              if (mounted && wasAllowed != nowAllowed) {
                print('🚨 Notification de changement d\'état affichée');
                if (!nowAllowed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _registrationErrorMessage ?? 'التسجيل غير متاح',
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('التسجيل متاح الآن'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            } else {
              print('⚠️ Données vides ou widget non monté');
            }
          },
          onError: (error) {
            print('❌ Erreur dans le stream: $error');
            if (mounted) {
              setState(() {
                _isRegistrationAllowed = false;
                _registrationErrorMessage = 'خطأ في التحقق من حالة المسابقة';
              });
            }
          },
        );
  }

  Future<void> _checkRegistrationStatus() async {
    try {
      final activeVersions =
          await _competitionService.fetchActiveVersionsWithOpenRegistration();
      final versionExists = activeVersions.any(
        (version) => version.id == widget.versionId,
      );

      if (!versionExists) {
        setState(() {
          _isRegistrationAllowed = false;
          _registrationErrorMessage = 'المسابقة غير نشطة أو التسجيل مغلق';
        });
      } else {
        setState(() {
          _isRegistrationAllowed = true;
          _registrationErrorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _isRegistrationAllowed = false;
        _registrationErrorMessage = 'خطأ في التحقق من حالة المسابقة';
      });
      print('Erreur lors de la vérification du statut d\'inscription: $e');
    }
  }

  Future<void> _checkAgeGroupLimit() async {
    try {
      // Récupérer les informations de la version
      final version = await _competitionService.getVersionById(
        widget.versionId,
      );
      if (version == null) {
        setState(() {
          _isRegistrationAllowed = false;
          _registrationErrorMessage = 'المسابقة غير موجودة';
        });
        return;
      }

      // Récupérer le nombre de participants pour ce groupe d'âge
      final participantCounts = await _competitionService
          .getParticipantCountsByAgeGroup(widget.versionId);

      final currentCount =
          widget.ageGroup == 'كبار'
              ? (participantCounts['adults'] ?? 0)
              : (participantCounts['children'] ?? 0);

      final maxCount =
          widget.ageGroup == 'كبار' ? version.maxAdults : version.maxChildren;

      print(
        '📊 Vérification limite: ${widget.ageGroup} = $currentCount/$maxCount',
      );

      if (currentCount >= maxCount) {
        setState(() {
          _isRegistrationAllowed = false;
          _registrationErrorMessage =
              'تم الوصول للحد الأقصى من المشاركين في فرع ${widget.ageGroup}';
        });

        // Afficher un SnackBar au lieu d'un dialog pour une meilleure UX
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم الوصول للحد الأقصى من المشاركين في فرع ${widget.ageGroup} (${maxCount} مشارك)',
              ),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'موافق',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(context).pop(); // Retourner à la page précédente
                },
              ),
            ),
          );
        }
        return;
      }
    } catch (e) {
      print('Erreur lors de la vérification de la limite du groupe d\'âge: $e');
      setState(() {
        _isRegistrationAllowed = false;
        _registrationErrorMessage = 'خطأ في التحقق من الحد الأقصى للمشاركين';
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (date != null) {
      setState(() {
        _selectedBirthDate = date;
        _birthDateController.text = date.toLocal().toString().split(' ')[0];
      });
    }
  }

  Future<void> _submit() async {
    // Vérifier en temps réel si l'inscription est toujours autorisée
    await _checkRegistrationStatus();

    if (!_isRegistrationAllowed) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              'التسجيل غير متاح',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: Text(
              _registrationErrorMessage ?? 'التسجيل غير متاح حالياً',
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.white,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Fermer le dialog
                  Navigator.of(context).pop(); // Retourner à la page précédente
                },
                child: const Text(
                  'موافق',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    // Vérifier si le groupe d'âge a atteint sa limite
    await _checkAgeGroupLimit();

    // Vérifier à nouveau juste avant l'inscription (double vérification)
    if (!_isRegistrationAllowed) {
      return; // Sortir si l'inscription n'est pas autorisée
    }

    if (!_formKey.currentState!.validate()) return;
    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار تاريخ الميلاد')),
      );
      return;
    }

    // Validation que tous les champs requis sont remplis
    if (_gender == null || _gender!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الجنس'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_quranMemorized == null || _quranMemorized!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار مستوى الحفظ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_readingMethods == null || _readingMethods!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار عدد الروايات'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_residence == null || _residence!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار مكان الإقامة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Règle métier 2 : Si wonPreviousRanks == true, alors participatedBefore doit être automatiquement true
    if (_wonPreviousRanks && !_participatedBefore) {
      setState(() {
        _participatedBefore = true;
      });
    }

    setState(() {
      _isLoading = true;
      print('🔄 Loading démarré: $_isLoading');
    });

    // Vérification finale des limites juste avant l'inscription
    await _checkAgeGroupLimit();
    if (!_isRegistrationAllowed) {
      setState(() => _isLoading = false);
      return;
    }

    // Déterminer si le participant doit être automatiquement refusé
    final bool isOutsideCountry = _residence == 'خارج موريتانيا';
    final bool hasWonPreviousRanks = _wonPreviousRanks;
    final bool shouldAutoReject = isOutsideCountry || hasWonPreviousRanks;

    // Déterminer la raison de refus
    String? rejectionReason;
    if (shouldAutoReject) {
      if (isOutsideCountry && hasWonPreviousRanks) {
        rejectionReason =
            'الإقامة خارج موريتانيا وحصوله على المرتبة الأولى أو الثانية في مسابقة سابقة';
      } else if (isOutsideCountry) {
        rejectionReason = 'الإقامة خارج موريتانيا';
      } else if (hasWonPreviousRanks) {
        rejectionReason = 'حصوله على المرتبة الأولى أو الثانية في مسابقة سابقة';
      }
      print('🚫 Raison de refus déterminée: $rejectionReason');
    }

    final participant = Participant(
      id: '',
      fullName: _fullNameController.text.trim(),
      gender: _gender!,
      birthDate: _selectedBirthDate!,
      phone: _phoneController.text.trim(),
      quranMemorized: _quranMemorized!,
      readingMethods: _readingMethods!,
      residence: _residence!,
      hasIjaza: _hasIjaza,
      wonPreviousRanks: _wonPreviousRanks,
      participatedBefore: _participatedBefore,
      ageGroup: widget.ageGroup,
      createdAt: DateTime.now(),
      isAccepted:
          !shouldAutoReject, // Automatiquement refusé si conditions remplies
      rejectionReason: rejectionReason, // Ajouter la raison de refus
    );

    try {
      final result = await _service.registerParticipant(
        participant: participant,
        versionId: widget.versionId,
      );

      // Extraire le numéro d'enregistrement du résultat
      String registrationNumber = 'غير محدد';
      try {
        // Traiter result comme dynamic pour éviter les erreurs de type
        final dynamic resultData = result;
        if (resultData is Map<String, dynamic>) {
          final regNum = resultData['registration_number'];
          registrationNumber = regNum?.toString() ?? 'غير محدد';
        } else {
          // Si result est un int (numéro d'enregistrement direct)
          registrationNumber = resultData.toString();
        }
      } catch (e) {
        // Garder la valeur par défaut
        print('Erreur lors de l\'extraction du numéro d\'enregistrement: $e');
      }

      // Convertir le numéro d'enregistrement en français
      final String frenchRegistrationNumber = _convertToFrenchNumbers(
        registrationNumber,
      );

      // Message personnalisé selon le statut d'acceptation
      final ageGroupText = widget.ageGroup == 'كبار' ? 'الكبار' : 'الصغار';
      String message;
      if (shouldAutoReject) {
        if (isOutsideCountry && hasWonPreviousRanks) {
          message =
              'تم تسجيلك بنجاح في فرع $ageGroupText برقم التسجيل: $frenchRegistrationNumber\n\nلكن تم رفض طلبك تلقائياً للأسباب التالية:\n• الإقامة خارج موريتانيا\n• حصولك على المرتبة الأولى أو الثانية في مسابقة سابقة';
        } else if (isOutsideCountry) {
          message =
              'تم تسجيلك بنجاح في فرع $ageGroupText برقم التسجيل: $frenchRegistrationNumber\n\nلكن تم رفض طلبك تلقائياً لأنك تقيم خارج موريتانيا';
        } else {
          message =
              'تم تسجيلك بنجاح في فرع $ageGroupText برقم التسجيل: $frenchRegistrationNumber\n\nلكن تم رفض طلبك تلقائياً لأنك حصلت على المرتبة الأولى أو الثانية في مسابقة سابقة';
        }
      } else {
        message =
            'تم تسجيلك بنجاح في فرع $ageGroupText برقم التسجيل: $frenchRegistrationNumber';
      }

      // Arrêter le loading avant d'afficher le dialog de succès
      setState(() {
        _isLoading = false;
        print('✅ Loading arrêté (succès): $_isLoading');
      });

      // Afficher le message dans un dialog au lieu d'un SnackBar
      showDialog(
        context: context,
        barrierDismissible: false, // L'utilisateur doit cliquer sur OK
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              shouldAutoReject ? 'تم التسجيل مع رفض الطلب' : 'تم التسجيل بنجاح',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: Text(message, style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.white,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Fermer le dialog
                  Navigator.of(context).pop(); // Retourner à la page précédente
                },
                child: const Text(
                  'موافق',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('فشل التسجيل: $e');

      // Arrêter le loading avant d'afficher l'erreur
      setState(() {
        _isLoading = false;
        print('❌ Loading arrêté (erreur): $_isLoading');
      });

      // Message d'erreur plus convivial pour l'utilisateur
      String errorMessage = 'حدث خطأ أثناء التسجيل';
      Color backgroundColor = Colors.red;

      if (e.toString().contains(
        'type \'Null\' is not a subtype of type \'int\'',
      )) {
        errorMessage = 'تم التسجيل بنجاح ولكن حدث خطأ في معالجة البيانات';
        backgroundColor = Colors.orange; // Orange car l'inscription a réussi
      } else if (e.toString().contains('is_accepted') &&
          e.toString().contains('null')) {
        errorMessage = 'تم التسجيل بنجاح ولكن حدث خطأ في تحديد حالة القبول';
        backgroundColor = Colors.orange; // Orange car l'inscription a réussi
      } else if (e.toString().contains('التسجيل غير متاح لهذه المسابقة')) {
        errorMessage = 'التسجيل غير متاح لهذه المسابقة';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage = 'خطأ في الاتصال، تحقق من اتصال الإنترنت';
      } else if (e.toString().contains('duplicate') ||
          e.toString().contains('already exists')) {
        errorMessage = 'هذا المشارك مسجل مسبقاً';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 4),
        ),
      );

      // Si c'est une erreur de type cast mais que l'inscription a probablement réussi, fermer quand même
      if (e.toString().contains(
        'type \'Null\' is not a subtype of type \'int\'',
      )) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: widget.ageGroup == "كبار" ? 'تسجيل الكبار' : 'تسجيل الصغار',
        actions: [
          // Bouton de test pour forcer une vérification
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Vérifier le statut',
            onPressed: () {},
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('جاري التسجيل...'),
                  ],
                ),
              )
              : ModernPullToRefresh(
                onRefresh: () async {
                  // Simuler un refresh
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Message d'information si l'inscription n'est pas autorisée
                        if (!_isRegistrationAllowed &&
                            _registrationErrorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            margin: const EdgeInsets.only(
                              bottom: AppTheme.spacingS,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 32,
                                ),
                                const SizedBox(height: AppTheme.spacingS),
                                Text(
                                  'التسجيل غير متاح',
                                  style: AppTheme.labelLarge.copyWith(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTheme.spacingS),
                                Text(
                                  _registrationErrorMessage!,
                                  style: AppTheme.labelMedium.copyWith(
                                    color: Colors.red[700],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Section des informations personnelles
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
                                        Icons.person,
                                        color: AppTheme.primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Text(
                                      'المعلومات الشخصية',
                                      style: AppTheme.labelLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.spacingS),

                                TextFormField(
                                  controller: _fullNameController,
                                  decoration: InputDecoration(
                                    labelText: 'الاسم الثلاثي',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                    ),
                                  ),
                                  validator:
                                      (v) =>
                                          v == null || v.isEmpty
                                              ? 'هذا الحقل مطلوب'
                                              : null,
                                ),
                                const SizedBox(height: AppTheme.spacingS),

                                DropdownButtonFormField<String>(
                                  value: _gender,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'ذكر',
                                      child: Text('ذكر'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'أنثى',
                                      child: Text('أنثى'),
                                    ),
                                  ],
                                  onChanged:
                                      (value) =>
                                          setState(() => _gender = value),
                                  decoration: InputDecoration(
                                    labelText: 'الجنس',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                    ),
                                  ),
                                  validator:
                                      (v) => v == null ? 'اختر الجنس' : null,
                                ),
                                const SizedBox(height: AppTheme.spacingS),

                                TextFormField(
                                  controller: _birthDateController,
                                  readOnly: true,
                                  onTap: _pickBirthDate,
                                  decoration: InputDecoration(
                                    labelText: 'تاريخ الميلاد',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                    ),
                                  ),
                                  validator:
                                      (v) =>
                                          v == null || v.isEmpty
                                              ? 'هذا الحقل مطلوب'
                                              : null,
                                ),
                                const SizedBox(height: AppTheme.spacingS),

                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'رقم الهاتف',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                    ),
                                  ),
                                  validator:
                                      (v) =>
                                          v == null || v.isEmpty
                                              ? 'هذا الحقل مطلوب'
                                              : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        // Section des المعلومات القرآنية
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
                                        color: AppTheme.successColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusM,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.menu_book,
                                        color: AppTheme.successColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Text(
                                      'المعلومات القرآنية',
                                      style: AppTheme.labelLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.spacingS),

                                DropdownButtonFormField<String>(
                                  value: _quranMemorized,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'القرآن كاملاً',
                                      child: Text('القرآن كاملاً'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'نصف القرآن',
                                      child: Text('نصف القرآن'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'أقل من نصف',
                                      child: Text('أقل من نصف'),
                                    ),
                                  ],
                                  onChanged:
                                      (value) => setState(
                                        () => _quranMemorized = value,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: 'كم تحفظ من القرآن',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                    ),
                                  ),
                                  validator:
                                      (v) =>
                                          v == null || v.isEmpty
                                              ? 'اختر مستوى الحفظ'
                                              : null,
                                ),
                                const SizedBox(height: AppTheme.spacingS),

                                DropdownButtonFormField<String>(
                                  value: _readingMethods,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'رواية واحدة',
                                      child: Text('رواية واحدة'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'أكثر من رواية',
                                      child: Text('أكثر من رواية'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _readingMethods = value;
                                      // Règle métier 1 : Si plus d'une rواية, alors القرآن كاملاً automatiquement
                                      if (value == 'أكثر من رواية') {
                                        _quranMemorized = 'القرآن كاملاً';
                                      }
                                      // Si رواية واحدة, alors pas d'إجازة
                                      else if (value == 'رواية واحدة') {
                                        _hasIjaza = false;
                                      }
                                    });
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'كم رواية تقرأ بها',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                    ),
                                  ),
                                  validator:
                                      (v) =>
                                          v == null || v.isEmpty
                                              ? 'اختر عدد الروايات'
                                              : null,
                                ),
                                const SizedBox(height: AppTheme.spacingS),

                                DropdownButtonFormField<String>(
                                  value: _residence,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'داخل موريتانيا',
                                      child: Text('داخل موريتانيا'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'خارج موريتانيا',
                                      child: Text('خارج موريتانيا'),
                                    ),
                                  ],
                                  onChanged:
                                      (value) =>
                                          setState(() => _residence = value),
                                  decoration: InputDecoration(
                                    labelText: 'مكان الإقامة الحالية',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                    ),
                                  ),
                                  validator:
                                      (v) =>
                                          v == null || v.isEmpty
                                              ? 'اختر مكان الإقامة'
                                              : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),

                        // Section des questions supplémentaires
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
                                        color: AppTheme.warningColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusM,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.help_outline,
                                        color: AppTheme.warningColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Text(
                                      'أسئلة إضافية',
                                      style: AppTheme.labelLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.spacingS),

                                _buildSwitchTile(
                                  title: 'هل حصلت على إجازة؟',
                                  value: _hasIjaza,
                                  onChanged: (v) {
                                    setState(() {
                                      _hasIjaza = v;
                                      // Règle métier 1 : Si إجازة, alors القرآن كاملاً automatiquement
                                      if (v) {
                                        _quranMemorized = 'القرآن كاملاً';
                                      }
                                      // Si pas d'إجازة, alors forcément رواية واحدة
                                      else if (!v) {
                                        _readingMethods = 'رواية واحدة';
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: AppTheme.spacingS),

                                _buildSwitchTile(
                                  title: 'هل شاركت في نسخة ماضية؟',
                                  value: _participatedBefore,
                                  onChanged: (v) {
                                    setState(() {
                                      _participatedBefore = v;
                                      // Si on décoche "شاركت في نسخة ماضية", alors décocher automatiquement "حصلت على المراتب"
                                      if (!v) {
                                        _wonPreviousRanks = false;
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: AppTheme.spacingS),

                                _buildSwitchTile(
                                  title:
                                      'هل حصلت على المراتب 1 إلى 2 في مسابقة أهل القرآن أو غيرها؟',
                                  value: _wonPreviousRanks,
                                  onChanged: (v) {
                                    setState(() {
                                      _wonPreviousRanks = v;
                                      // Règle métier 2 : Si wonPreviousRanks devient true, participatedBefore devient automatiquement true
                                      if (v) {
                                        _participatedBefore = true;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),

                        // Bouton de soumission
                        SizedBox(
                          width: double.infinity,
                          child: Builder(
                            builder: (context) {
                              print(
                                '🔘 Bouton rebuild - _isLoading: $_isLoading, _isRegistrationAllowed: $_isRegistrationAllowed',
                              );
                              return PrimaryButton(
                                onPressed:
                                    (_isRegistrationAllowed && !_isLoading)
                                        ? _submit
                                        : null,
                                text:
                                    _isLoading
                                        ? 'جاري التسجيل...'
                                        : (_isRegistrationAllowed
                                            ? 'تسجيل'
                                            : 'التسجيل غير متاح'),
                                isLoading: _isLoading,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  // Fonction pour convertir les chiffres arabes en français
  String _convertToFrenchNumbers(String text) {
    const Map<String, String> arabicToFrench = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };

    String result = text;
    arabicToFrench.forEach((arabic, french) {
      result = result.replaceAll(arabic, french);
    });
    return result;
  }
}
