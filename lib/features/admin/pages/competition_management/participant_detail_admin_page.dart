import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../models/participant.dart';
import '../../../../models/competition_version.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/participant_service.dart';
import '../../../../core/services/confirmation_service.dart';

class ParticipantDetailPage extends StatefulWidget {
  final Participant participant;
  final CompetitionVersion version;

  const ParticipantDetailPage({
    super.key,
    required this.participant,
    required this.version,
  });

  @override
  State<ParticipantDetailPage> createState() => _ParticipantDetailPageState();
}

class _ParticipantDetailPageState extends State<ParticipantDetailPage> {
  final ParticipantService _participantService = ParticipantService();
  bool _isLoading = false;
  bool _isEditing = false;
  bool _areResultsPublished = false;
  bool _isCheckingResults = false;

  // Controllers pour l'édition
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _residenceController = TextEditingController();

  // Variables d'état pour l'édition
  String? _selectedGender;
  String? _selectedAgeGroup;
  String? _selectedQuranMemorized;
  String? _selectedReadingMethods;
  String? _selectedResidence;
  bool? _hasIjaza;
  bool? _participatedBefore;
  bool? _wonPreviousRanks;
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _checkResultsPublished();
  }

  Future<void> _checkResultsPublished() async {
    setState(() => _isCheckingResults = true);
    try {
      final supabase = Supabase.instance.client;

      // Récupérer tous les rounds de cette version
      final roundsResponse = await supabase
          .from('rounds')
          .select('id, result_is_published')
          .eq('version_id', widget.version.id);

      // Vérifier si au moins un round a des résultats publiés
      final hasPublishedResults = roundsResponse.any(
        (round) => round['result_is_published'] == true,
      );

      if (mounted) {
        setState(() {
          _areResultsPublished = hasPublishedResults;
          _isCheckingResults = false;
        });
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification des résultats publiés: $e');
      if (mounted) {
        setState(() => _isCheckingResults = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _residenceController.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    _nameController.text = widget.participant.fullName;
    _phoneController.text = widget.participant.phone;
    _selectedGender = widget.participant.gender;
    _selectedAgeGroup = widget.participant.ageGroup;

    // Valider et normaliser les valeurs des dropdowns
    final quranOptions = ['القرآن كاملاً', 'نصف القرآن', 'أقل من نصف'];
    _selectedQuranMemorized =
        quranOptions.contains(widget.participant.quranMemorized)
            ? widget.participant.quranMemorized
            : quranOptions.first;

    final readingOptions = ['رواية واحدة', 'أكثر من رواية'];
    _selectedReadingMethods =
        readingOptions.contains(widget.participant.readingMethods)
            ? widget.participant.readingMethods
            : readingOptions.first;

    final residenceOptions = ['خارج موريتانيا', 'داخل موريتانيا'];
    _selectedResidence =
        residenceOptions.contains(widget.participant.residence)
            ? widget.participant.residence
            : residenceOptions.first;

    _hasIjaza = widget.participant.hasIjaza;
    _participatedBefore = widget.participant.participatedBefore;
    _wonPreviousRanks = widget.participant.wonPreviousRanks;
    _birthDate = widget.participant.birthDate;
  }

  bool get _canEditParticipant {
    return widget.version.isActive &&
        !widget.version.juryEvaluationEnabled &&
        !_areResultsPublished;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'تفاصيل المشارك',
        actions: [
          IconButton(
            icon:
                _isCheckingResults
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.surfaceColor,
                        ),
                      ),
                    )
                    : Icon(
                      _isEditing ? Icons.close_rounded : Icons.edit_rounded,
                      color: AppTheme.surfaceColor,
                    ),
            onPressed:
                _isCheckingResults
                    ? null
                    : (_canEditParticipant
                        ? () {
                          setState(() {
                            if (_isEditing) {
                              _initializeControllers(); // Réinitialiser les valeurs
                            }
                            _isEditing = !_isEditing;
                          });
                        }
                        : () {
                          String message;
                          if (!widget.version.isActive) {
                            message = 'لا يمكن التعديل: النسخة غير نشطة';
                          } else if (widget.version.juryEvaluationEnabled) {
                            message =
                                'لا يمكن التعديل أثناء تفعيل تقييم المحكمين';
                          } else if (_areResultsPublished) {
                            message = 'لا يمكن التعديل: نتائج الجولات منشورة';
                          } else {
                            message = 'لا يمكن التعديل';
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: AppTheme.warningColor,
                            ),
                          );
                        }),
            tooltip:
                _isCheckingResults
                    ? 'جاري التحقق...'
                    : (_canEditParticipant
                        ? (_isEditing ? 'إلغاء التعديل' : 'تعديل')
                        : 'التعديل غير متاح'),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppTheme.surfaceColor),
            onSelected: (value) {
              switch (value) {
                case 'delete':
                  _showDeleteConfirmation();
                  break;
                case 'reject':
                  _showRejectConfirmation();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem<String>(
                    value: 'reject',
                    child: Row(
                      children: [
                        Icon(Icons.cancel_rounded, color: AppTheme.warningColor),
                        const SizedBox(width: AppTheme.spacingS),
                        const Text('إلغاء المشاركة'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, color: AppTheme.errorColor),
                        const SizedBox(width: AppTheme.spacingS),
                        const Text('حذف'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : Container(
                // Le « tirer pour actualiser » ne rechargeait rien : retiré
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: AppTheme.spacingM),

                      // Statut affiché dans l'en-tête ; ici seulement le motif du refus
                      if (!_isEditing &&
                          !widget.participant.isAccepted &&
                          (widget.participant.rejectionReason ?? '').isNotEmpty)
                        AppNotice(
                          text:
                              'سبب الرفض: ${widget.participant.rejectionReason}',
                          color: AppTheme.errorColor,
                          icon: Icons.info_outline_rounded,
                        ),

                      // Section changement de statut (en mode édition)
                      if (_isEditing && _canEditParticipant)
                        ModernCard(
                          child: Container(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            decoration: BoxDecoration(
                              color:
                                  widget.participant.isAccepted == true
                                      ? AppTheme.successColor.withOpacity(0.1)
                                      : AppTheme.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                              border: Border.all(
                                color:
                                    widget.participant.isAccepted == true
                                        ? AppTheme.successColor.withOpacity(0.3)
                                        : AppTheme.errorColor.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified_user_rounded,
                                      color:
                                          widget.participant.isAccepted == true
                                              ? AppTheme.successColor
                                              : AppTheme.errorColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Text(
                                      'حالة المشاركة',
                                      style: AppTheme.headingSmall.copyWith(
                                        color:
                                            widget.participant.isAccepted ==
                                                    true
                                                ? AppTheme.successColor
                                                : AppTheme.errorColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.spacingS),
                                Row(
                                  children: [
                                    Expanded(
                                      child: PrimaryButton(
                                        onPressed:
                                            widget.participant.isAccepted ==
                                                    true
                                                ? _showRejectConfirmation
                                                : _acceptParticipant,
                                        text:
                                            widget.participant.isAccepted ==
                                                    true
                                                ? 'إلغاء المشاركة'
                                                : 'قبول المشاركة',
                                        icon:
                                            widget.participant.isAccepted ==
                                                    true
                                                ? Icons.cancel_rounded
                                                : Icons.check_rounded,
                                        backgroundColor:
                                            widget.participant.isAccepted ==
                                                    true
                                                ? AppTheme.errorColor
                                                : AppTheme.successColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Message d'information si l'édition n'est pas disponible
                      if (!_canEditParticipant)
                        ModernCard(
                          child: Container(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                              border: Border.all(
                                color: AppTheme.warningColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: AppTheme.warningColor,
                                  size: 24,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Expanded(
                                  child: Text(
                                    _isCheckingResults
                                        ? 'جاري التحقق من حالة النتائج...'
                                        : (!widget.version.isActive
                                            ? 'لا يمكن تعديل معلومات المشارك: النسخة غير نشطة'
                                            : widget
                                                .version
                                                .juryEvaluationEnabled
                                            ? 'لا يمكن تعديل معلومات المشارك أثناء تفعيل تقييم المحكمين'
                                            : _areResultsPublished
                                            ? 'لا يمكن تعديل معلومات المشارك: نتائج الجولات منشورة'
                                            : 'لا يمكن تعديل معلومات المشارك'),
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.warningColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: AppTheme.spacingM),

                      // المعلومات الشخصية
                      AppSection(
                        icon: Icons.person_outline_rounded,
                        color: AppTheme.primaryColor,
                        title: 'المعلومات الشخصية',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _isEditing && _canEditParticipant
                                ? _buildEditableTextField(
                                  icon: Icons.person_rounded,
                                  label: 'الاسم الكامل',
                                  controller: _nameController,
                                )
                                : _buildInfoRow(
                                  icon: Icons.person_rounded,
                                  label: 'الاسم الكامل',
                                  value: widget.participant.fullName,
                                ),
                            const SizedBox(height: AppTheme.spacingS),

                            _buildInfoRow(
                              icon: Icons.numbers_rounded,
                              label: 'رقم التسجيل',
                              value:
                                  widget.participant.registrationNumber
                                      ?.toString() ??
                                  'غير محدد',
                            ),
                            const SizedBox(height: AppTheme.spacingS),

                            _buildInfoRow(
                              icon:
                                  widget.participant.gender == 'ذكر'
                                      ? Icons.male_rounded
                                      : Icons.female_rounded,
                              label: 'الجنس',
                              value: widget.participant.gender,
                            ),
                            const SizedBox(height: AppTheme.spacingS),

                            _buildInfoRow(
                              icon: Icons.cake_rounded,
                              label: 'تاريخ الميلاد',
                              value:
                                  '${widget.participant.birthDate.day}/${widget.participant.birthDate.month}/${widget.participant.birthDate.year}',
                            ),
                            const SizedBox(height: AppTheme.spacingS),

                            _isEditing && _canEditParticipant
                                ? _buildEditableTextField(
                                  icon: Icons.phone_rounded,
                                  label: 'رقم الهاتف',
                                  controller: _phoneController,
                                )
                                : _buildInfoRow(
                                  icon: Icons.phone_rounded,
                                  label: 'رقم الهاتف',
                                  value: widget.participant.phone,
                                ),
                            const SizedBox(height: AppTheme.spacingS),

                            _isEditing && _canEditParticipant
                                ? _buildDropdownField(
                                  icon: Icons.location_on_rounded,
                                  label: 'مكان الإقامة',
                                  value:
                                      _selectedResidence ??
                                      widget.participant.residence,
                                  items: const [
                                    'خارج موريتانيا',
                                    'داخل موريتانيا',
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedResidence = value;
                                    });
                                  },
                                )
                                : _buildInfoRow(
                                  icon: Icons.location_on_rounded,
                                  label: 'مكان الإقامة',
                                  value: widget.participant.residence,
                                ),
                            const SizedBox(height: AppTheme.spacingS),

                            _isEditing && _canEditParticipant
                                ? _buildDropdownField(
                                  icon: Icons.people_rounded,
                                  label: 'الفئة العمرية',
                                  value:
                                      _selectedAgeGroup ??
                                      widget.participant.ageGroup,
                                  items: const ['كبار', 'صغار'],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedAgeGroup = value;
                                    });
                                  },
                                )
                                : _buildInfoRow(
                                  icon:
                                      widget.participant.ageGroup == 'كبار'
                                          ? Icons.person_rounded
                                          : Icons.person_rounded,
                                  label: 'الفئة العمرية',
                                  value: widget.participant.ageGroup,
                                ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),

                      // المعلومات القرآنية
                      AppSection(
                        icon: Icons.menu_book_rounded,
                        color: AppTheme.successColor,
                        title: 'المعلومات القرآنية',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _isEditing && _canEditParticipant
                                ? _buildDropdownField(
                                  icon: Icons.menu_book_rounded,
                                  label: 'كم حفظ من القرآن',
                                  value:
                                      _selectedQuranMemorized ??
                                      widget.participant.quranMemorized,
                                  items: const [
                                    'القرآن كاملاً',
                                    'نصف القرآن',
                                    'أقل من نصف',
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedQuranMemorized = value;
                                    });
                                  },
                                )
                                : _buildInfoRow(
                                  icon: Icons.menu_book_rounded,
                                  label: 'كم حفظ من القرآن',
                                  value: widget.participant.quranMemorized,
                                ),
                            const SizedBox(height: AppTheme.spacingS),

                            _isEditing && _canEditParticipant
                                ? _buildDropdownField(
                                  icon: Icons.format_list_numbered_rounded,
                                  label: 'عدد الروايات',
                                  value:
                                      _selectedReadingMethods ??
                                      widget.participant.readingMethods,
                                  items: const ['رواية واحدة', 'أكثر من رواية'],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedReadingMethods = value;
                                    });
                                  },
                                )
                                : _buildInfoRow(
                                  icon: Icons.format_list_numbered_rounded,
                                  label: 'عدد الروايات',
                                  value: widget.participant.readingMethods,
                                ),
                            const SizedBox(height: AppTheme.spacingS),

                            _buildInfoRow(
                              icon:
                                  widget.participant.hasIjaza
                                      ? Icons.verified_rounded
                                      : Icons.verified_rounded,
                              label: 'الإجازة',
                              value:
                                  widget.participant.hasIjaza
                                      ? 'لديه إجازة'
                                      : 'لا يملك إجازة',
                              valueColor:
                                  widget.participant.hasIjaza
                                      ? AppTheme.successColor
                                      : AppTheme.textSecondaryColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),

                      // معلومات النسخة
                      AppSection(
                        icon: Icons.emoji_events_rounded,
                        color: AppTheme.secondaryColor,
                        title: 'معلومات النسخة',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              icon: Icons.emoji_events_rounded,
                              label: 'اسم النسخة',
                              value: widget.version.name,
                            ),
                            const SizedBox(height: AppTheme.spacingS),

                            _buildInfoRow(
                              icon: Icons.calendar_today_rounded,
                              label: 'السنة',
                              value: widget.version.year.toString(),
                            ),
                            const SizedBox(height: AppTheme.spacingS),

                            _buildInfoRow(
                              icon: Icons.calendar_today_rounded,
                              label: 'تاريخ التسجيل',
                              value:
                                  '${widget.participant.createdAt.day}/${widget.participant.createdAt.month}/${widget.participant.createdAt.year}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),

                      // Actions d'édition
                      if (_isEditing) ...[
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            onPressed: _saveChanges,
                            text: 'حفظ التغييرات',
                            icon: Icons.save_rounded,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        SizedBox(
                          width: double.infinity,
                          child: SecondaryButton(
                            onPressed: () {
                              setState(() {
                                _initializeControllers();
                                _isEditing = false;
                              });
                            },
                            text: 'إلغاء',
                            icon: Icons.close_rounded,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppTheme.spacingS),
                    ],
                  ),
                ),
              ),
    );
  }

  /// En-tête : identité du participant sur fond dégradé
  Widget _buildHeaderCard() {
    final p = widget.participant;
    final isMale = p.gender == 'ذكر';
    final isAdult = p.ageGroup == 'كبار';

    return AppGradientHeader(
      shape: AppHeaderShape.card,
      leading: CircleAvatar(
        radius: 36,
        backgroundColor: Colors.white,
        child: Icon(
          isMale ? Icons.male_rounded : Icons.female_rounded,
          size: 38,
          color: isMale ? AppTheme.infoColor : AppTheme.accentColor,
        ),
      ),
      title: p.fullName,
      badges: [
        AppHeaderBadge(
          icon: Icons.confirmation_number_rounded,
          text: 'رقم التسجيل ${p.registrationNumber?.toString() ?? 'غير محدد'}',
        ),
        AppHeaderBadge(
          icon: Icons.people_rounded,
          text: isAdult ? 'فئة الكبار' : 'فئة الصغار',
        ),
        AppHeaderBadge(
          icon: p.isAccepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
          text: p.isAccepted ? 'مقبول' : 'مرفوض',
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 16),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required IconData icon,
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    // Vérifier que la valeur existe dans les items, sinon utiliser le premier item
    final validValue = items.contains(value) ? value : items.first;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 16),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingS,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.dividerColor),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: validValue,
                    isExpanded: true,
                    onChanged: onChanged,
                    items:
                        items.map((String item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(
                              item,
                              style: AppTheme.labelMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await ConfirmationService.showDeleteConfirmation(
      context,
      title: 'حذف المشارك',
      message:
          'هل أنت متأكد من حذف ${widget.participant.fullName}؟\nهذا الإجراء لا يمكن التراجع عنه.',
    );

    if (confirmed == true) {
      await _deleteParticipant();
    }
  }

  Future<void> _showRejectConfirmation() async {
    // Vérifier les conditions avant de rejeter
    if (!_canEditParticipant) {
      String message;
      if (!widget.version.isActive) {
        message = 'لا يمكن إلغاء المشاركة: النسخة غير نشطة';
      } else if (widget.version.juryEvaluationEnabled) {
        message = 'لا يمكن إلغاء المشاركة أثناء تفعيل تقييم المحكمين';
      } else if (_areResultsPublished) {
        message = 'لا يمكن إلغاء المشاركة: نتائج الجولات منشورة';
      } else {
        message = 'لا يمكن إلغاء المشاركة';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          title: Row(
            children: [
              Icon(Icons.cancel_rounded, color: AppTheme.errorColor),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'إلغاء المشاركة',
                style: AppTheme.headingSmall.copyWith(
                  color: AppTheme.errorColor,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من إلغاء مشاركة ${widget.participant.fullName}؟',
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'سبب الرفض (اختياري):',
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'أدخل سبب رفض المشارك...',
                  hintStyle: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    borderSide: BorderSide(color: AppTheme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    borderSide: BorderSide(color: AppTheme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    borderSide: BorderSide(color: AppTheme.primaryColor),
                  ),
                  contentPadding: const EdgeInsets.all(AppTheme.spacingS),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'إلغاء',
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
              ),
              child: Text(
                'إلغاء المشاركة',
                style: AppTheme.labelLarge.copyWith(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final reason = reasonController.text.trim();
      await _rejectParticipant(reason: reason.isEmpty ? null : reason);
    }

    reasonController.dispose();
  }

  Future<void> _deleteParticipant() async {
    setState(() => _isLoading = true);

    try {
      await _participantService.deleteParticipant(widget.participant.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف ${widget.participant.fullName} بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop(true); // Retour avec succès
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في حذف المشارك: $e'),
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

  Future<void> _rejectParticipant({String? reason}) async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Supprimer les résultats du participant dans round_results
      await supabase
          .from('round_results')
          .delete()
          .eq('participant_id', widget.participant.id);

      // 2. Mettre à jour le statut et la raison de refus
      await supabase
          .from('participants')
          .update({'is_accepted': false, 'rejection_reason': reason})
          .eq('id', widget.participant.id);

      if (mounted) {
        setState(() {
          widget.participant.isAccepted = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إلغاء مشاركة ${widget.participant.fullName} وحذف نتائجه',
            ),
            backgroundColor: AppTheme.warningColor,
          ),
        );

        // Recharger la page pour afficher la raison de refus
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إلغاء المشاركة: $e'),
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

  Future<void> _acceptParticipant() async {
    // Vérifier les conditions avant d'accepter
    if (!_canEditParticipant) {
      String message;
      if (!widget.version.isActive) {
        message = 'لا يمكن قبول المشارك: النسخة غير نشطة';
      } else if (widget.version.juryEvaluationEnabled) {
        message = 'لا يمكن قبول المشارك أثناء تفعيل تقييم المحكمين';
      } else if (_areResultsPublished) {
        message = 'لا يمكن قبول المشارك: نتائج الجولات منشورة';
      } else {
        message = 'لا يمكن قبول المشارك';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Mettre à jour le statut et effacer la raison de refus
      final supabase = Supabase.instance.client;
      await supabase
          .from('participants')
          .update({'is_accepted': true, 'rejection_reason': null})
          .eq('id', widget.participant.id);

      if (mounted) {
        setState(() {
          widget.participant.isAccepted = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم قبول مشاركة ${widget.participant.fullName}'),
            backgroundColor: AppTheme.successColor,
          ),
        );

        // Recharger la page pour mettre à jour l'affichage
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في قبول المشاركة: $e'),
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

  Widget _buildEditableTextField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 16),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 2),
              TextField(
                controller: controller,
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    borderSide: BorderSide(color: AppTheme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    borderSide: BorderSide(color: AppTheme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    borderSide: BorderSide(color: AppTheme.primaryColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingXS,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    // Vérifier les conditions avant de sauvegarder
    if (!_canEditParticipant) {
      String message;
      if (!widget.version.isActive) {
        message = 'لا يمكن حفظ التعديلات: النسخة غير نشطة';
      } else if (widget.version.juryEvaluationEnabled) {
        message = 'لا يمكن حفظ التعديلات أثناء تفعيل تقييم المحكمين';
      } else if (_areResultsPublished) {
        message = 'لا يمكن حفظ التعديلات: نتائج الجولات منشورة';
      } else {
        message = 'لا يمكن حفظ التعديلات';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Créer un objet participant mis à jour
      final updatedParticipant = Participant(
        id: widget.participant.id,
        fullName: _nameController.text.trim(),
        gender: _selectedGender ?? widget.participant.gender,
        birthDate: _birthDate ?? widget.participant.birthDate,
        phone: _phoneController.text.trim(),
        quranMemorized:
            _selectedQuranMemorized ?? widget.participant.quranMemorized,
        readingMethods:
            _selectedReadingMethods ?? widget.participant.readingMethods,
        residence: _selectedResidence ?? widget.participant.residence,
        hasIjaza: _hasIjaza ?? widget.participant.hasIjaza,
        wonPreviousRanks:
            _wonPreviousRanks ?? widget.participant.wonPreviousRanks,
        participatedBefore:
            _participatedBefore ?? widget.participant.participatedBefore,
        ageGroup: _selectedAgeGroup ?? widget.participant.ageGroup,
        passedRound1: widget.participant.passedRound1,
        createdAt: widget.participant.createdAt,
        isAccepted: widget.participant.isAccepted,
        registrationNumber: widget.participant.registrationNumber,
        rejectionReason: widget.participant.rejectionReason,
      );

      // Appeler le service pour mettre à jour (méthode simple)
      await _updateParticipantInfo(updatedParticipant);

      if (mounted) {
        // Mettre à jour l'objet participant local en recréant l'objet
        // Note: Les champs sont final, donc on ne peut pas les modifier directement

        setState(() {
          _isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ التغييرات بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في حفظ التغييرات: $e'),
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

  Future<void> _updateParticipantInfo(Participant updatedParticipant) async {
    final supabase = Supabase.instance.client;

    await supabase
        .from('participants')
        .update({
          'full_name': updatedParticipant.fullName,
          'phone': updatedParticipant.phone,
          'residence': updatedParticipant.residence,
          'quran_memorized': updatedParticipant.quranMemorized,
          'reading_methods': updatedParticipant.readingMethods,
          'age_group': updatedParticipant.ageGroup,
        })
        .eq('id', updatedParticipant.id);
  }
}
