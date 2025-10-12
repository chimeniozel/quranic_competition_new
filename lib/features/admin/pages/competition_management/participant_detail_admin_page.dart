import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'تفاصيل المشارك',
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.close : Icons.edit,
              color: AppTheme.surfaceColor,
            ),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  _initializeControllers(); // Réinitialiser les valeurs
                }
                _isEditing = !_isEditing;
              });
            },
            tooltip: _isEditing ? 'إلغاء التعديل' : 'تعديل',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppTheme.surfaceColor),
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
                        Icon(Icons.cancel, color: AppTheme.warningColor),
                        const SizedBox(width: AppTheme.spacingS),
                        const Text('إلغاء المشاركة'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppTheme.errorColor),
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
              : ModernPullToRefresh(
                onRefresh: () async {
                  // Recharger les données du participant
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    children: [
                      // Header avec photo et informations principales
                      ModernCard(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.1),
                                AppTheme.primaryColor.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusM,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingL),
                            child: Column(
                              children: [
                                // Avatar moderne avec genre
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor:
                                        widget.participant.gender == 'ذكر'
                                            ? Colors.blue.withOpacity(0.1)
                                            : Colors.pink.withOpacity(0.1),
                                    child: Icon(
                                      widget.participant.gender == 'ذكر'
                                          ? Icons.male
                                          : Icons.female,
                                      size: 50,
                                      color:
                                          widget.participant.gender == 'ذكر'
                                              ? Colors.blue
                                              : Colors.pink,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingM),

                                // Nom complet
                                Text(
                                  widget.participant.fullName,
                                  style: AppTheme.headingMedium.copyWith(
                                    color: AppTheme.primaryColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTheme.spacingS),

                                // Groupe d'âge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingM,
                                    vertical: AppTheme.spacingS,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        widget.participant.ageGroup == 'كبار'
                                            ? Colors.blue.withOpacity(0.1)
                                            : Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                    border: Border.all(
                                      color:
                                          widget.participant.ageGroup == 'كبار'
                                              ? Colors.blue
                                              : Colors.purple,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.people,
                                        color:
                                            widget.participant.ageGroup ==
                                                    'كبار'
                                                ? Colors.blue
                                                : Colors.purple,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppTheme.spacingS),
                                      Text(
                                        widget.participant.ageGroup == 'كبار'
                                            ? 'فئة الكبار'
                                            : 'فئة الصغار',
                                        style: AppTheme.labelLarge.copyWith(
                                          color:
                                              widget.participant.ageGroup ==
                                                      'كبار'
                                                  ? Colors.blue
                                                  : Colors.purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingM),

                                // Numéro d'enregistrement
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(
                                    AppTheme.spacingM,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                    border: Border.all(
                                      color: AppTheme.dividerColor,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(
                                          AppTheme.spacingS,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.confirmation_number,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacingM),
                                      Text(
                                        'رقم التسجيل',
                                        style: AppTheme.labelMedium,
                                      ),
                                      const SizedBox(width: AppTheme.spacingS),
                                      Text(
                                        widget.participant.registrationNumber
                                                ?.toString() ??
                                            'غير محدد',
                                        style: AppTheme.headingSmall.copyWith(
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Section changement de statut (en haut) - Affichage uniquement
                      if (!_isEditing)
                        ModernCard(
                          child: Container(
                            padding: const EdgeInsets.all(AppTheme.spacingM),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  widget.participant.isAccepted == true
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  widget.participant.isAccepted == true
                                      ? Colors.green.withOpacity(0.05)
                                      : Colors.red.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                              border: Border.all(
                                color:
                                    widget.participant.isAccepted == true
                                        ? Colors.green.withOpacity(0.3)
                                        : Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      widget.participant.isAccepted == true
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color:
                                          widget.participant.isAccepted == true
                                              ? Colors.green
                                              : Colors.red,
                                      size: 28,
                                    ),
                                    const SizedBox(width: AppTheme.spacingM),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.participant.isAccepted ==
                                                    true
                                                ? 'مقبول'
                                                : 'مرفوض',
                                            style: AppTheme.headingMedium
                                                .copyWith(
                                                  color:
                                                      widget
                                                                  .participant
                                                                  .isAccepted ==
                                                              true
                                                          ? Colors.green[700]
                                                          : Colors.red[700],
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          if (widget.participant.isAccepted ==
                                                  false &&
                                              widget
                                                      .participant
                                                      .rejectionReason !=
                                                  null) ...[
                                            const SizedBox(
                                              height: AppTheme.spacingXS,
                                            ),
                                            Text(
                                              'السبب: ${widget.participant.rejectionReason}',
                                              style: AppTheme.bodyMedium
                                                  .copyWith(
                                                    color: Colors.red[600],
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Section changement de statut (en mode édition)
                      if (_isEditing)
                        ModernCard(
                          child: Container(
                            padding: const EdgeInsets.all(AppTheme.spacingM),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  widget.participant.isAccepted == true
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  widget.participant.isAccepted == true
                                      ? Colors.green.withOpacity(0.05)
                                      : Colors.red.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                              border: Border.all(
                                color:
                                    widget.participant.isAccepted == true
                                        ? Colors.green.withOpacity(0.3)
                                        : Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified_user,
                                      color:
                                          widget.participant.isAccepted == true
                                              ? Colors.green
                                              : Colors.red,
                                      size: 24,
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Text(
                                      'حالة المشاركة',
                                      style: AppTheme.headingSmall.copyWith(
                                        color:
                                            widget.participant.isAccepted ==
                                                    true
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.spacingM),
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
                                                ? Icons.cancel
                                                : Icons.check,
                                        backgroundColor:
                                            widget.participant.isAccepted ==
                                                    true
                                                ? Colors.red
                                                : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Section informations personnelles
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingM,
                        ),
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.1),
                              AppTheme.primaryColor.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingS),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusS,
                                ),
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Text(
                              'المعلومات الشخصية',
                              style: AppTheme.headingSmall.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Informations personnelles détaillées
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _isEditing
                                  ? _buildEditableTextField(
                                    icon: Icons.person,
                                    label: 'الاسم الكامل',
                                    controller: _nameController,
                                  )
                                  : _buildInfoRow(
                                    icon: Icons.person,
                                    label: 'الاسم الكامل',
                                    value: widget.participant.fullName,
                                  ),
                              const SizedBox(height: AppTheme.spacingS),

                              _buildInfoRow(
                                icon: Icons.numbers,
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
                                        ? Icons.male
                                        : Icons.female,
                                label: 'الجنس',
                                value: widget.participant.gender,
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              _buildInfoRow(
                                icon: Icons.cake,
                                label: 'تاريخ الميلاد',
                                value:
                                    '${widget.participant.birthDate.day}/${widget.participant.birthDate.month}/${widget.participant.birthDate.year}',
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              _isEditing
                                  ? _buildEditableTextField(
                                    icon: Icons.phone,
                                    label: 'رقم الهاتف',
                                    controller: _phoneController,
                                  )
                                  : _buildInfoRow(
                                    icon: Icons.phone,
                                    label: 'رقم الهاتف',
                                    value: widget.participant.phone,
                                  ),
                              const SizedBox(height: AppTheme.spacingS),

                              _isEditing
                                  ? _buildDropdownField(
                                    icon: Icons.location_on,
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
                                    icon: Icons.location_on,
                                    label: 'مكان الإقامة',
                                    value: widget.participant.residence,
                                  ),
                              const SizedBox(height: AppTheme.spacingS),

                              _buildInfoRow(
                                icon:
                                    widget.participant.ageGroup == 'كبار'
                                        ? Icons.person
                                        : Icons.child_care,
                                label: 'الفئة العمرية',
                                value: widget.participant.ageGroup,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Section informations القرآنية
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingM,
                        ),
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.green.withOpacity(0.1),
                              Colors.green.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingS),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusS,
                                ),
                              ),
                              child: const Icon(
                                Icons.menu_book_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Text(
                              'المعلومات القرآنية',
                              style: AppTheme.headingSmall.copyWith(
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Informations القرآنية
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _isEditing
                                  ? _buildDropdownField(
                                    icon: Icons.menu_book,
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
                                    icon: Icons.menu_book,
                                    label: 'كم حفظ من القرآن',
                                    value: widget.participant.quranMemorized,
                                  ),
                              const SizedBox(height: AppTheme.spacingS),

                              _isEditing
                                  ? _buildDropdownField(
                                    icon: Icons.format_list_numbered,
                                    label: 'عدد الروايات',
                                    value:
                                        _selectedReadingMethods ??
                                        widget.participant.readingMethods,
                                    items: const [
                                      'رواية واحدة',
                                      'أكثر من رواية',
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedReadingMethods = value;
                                      });
                                    },
                                  )
                                  : _buildInfoRow(
                                    icon: Icons.format_list_numbered,
                                    label: 'عدد الروايات',
                                    value: widget.participant.readingMethods,
                                  ),
                              const SizedBox(height: AppTheme.spacingS),

                              _buildInfoRow(
                                icon:
                                    widget.participant.hasIjaza
                                        ? Icons.verified
                                        : Icons.verified_outlined,
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
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Section معلومات المسابقة
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingM,
                        ),
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.purple.withOpacity(0.1),
                              Colors.purple.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingS),
                              decoration: BoxDecoration(
                                color: Colors.purple,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusS,
                                ),
                              ),
                              child: const Icon(
                                Icons.emoji_events,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Text(
                              'معلومات المسابقة',
                              style: AppTheme.headingSmall.copyWith(
                                color: Colors.purple[700],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Informations de la compétition
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                icon: Icons.emoji_events,
                                label: 'اسم المسابقة',
                                value: widget.version.name,
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              _buildInfoRow(
                                icon: Icons.calendar_today,
                                label: 'السنة',
                                value: widget.version.year.toString(),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              _buildInfoRow(
                                icon: Icons.calendar_today,
                                label: 'تاريخ التسجيل',
                                value:
                                    '${widget.participant.createdAt.day}/${widget.participant.createdAt.month}/${widget.participant.createdAt.year}',
                              ),
                            ],
                          ),
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
                            icon: Icons.save,
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
                            icon: Icons.close,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppTheme.spacingM),
                    ],
                  ),
                ),
              ),
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
              Icon(Icons.cancel, color: AppTheme.errorColor),
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
              const SizedBox(height: AppTheme.spacingM),
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
                  contentPadding: const EdgeInsets.all(AppTheme.spacingM),
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
      // Mettre à jour le statut et la raison de refus
      final supabase = Supabase.instance.client;
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
            content: Text('تم إلغاء مشاركة ${widget.participant.fullName}'),
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
        })
        .eq('id', updatedParticipant.id);
  }
}
