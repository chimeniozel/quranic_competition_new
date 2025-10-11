import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'تفاصيل المشارك',
        actions: [
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
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: Column(
                            children: [
                              // Avatar avec informations
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color:
                                      widget.participant.ageGroup == 'كبار'
                                          ? AppTheme.primaryColor
                                          : AppTheme.secondaryColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.participant.registrationNumber
                                              ?.toString() ??
                                          '؟',
                                      style: AppTheme.bodyLarge.copyWith(
                                        color: AppTheme.surfaceColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _calculateAge().toString(),
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.surfaceColor.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Nom complet
                              Text(
                                widget.participant.fullName,
                                style: AppTheme.labelLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Catégorie avec badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingS,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      widget.participant.ageGroup == 'كبار'
                                          ? AppTheme.primaryColor.withValues(
                                            alpha: 0.1,
                                          )
                                          : AppTheme.secondaryColor.withValues(
                                            alpha: 0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusS,
                                  ),
                                  border: Border.all(
                                    color:
                                        widget.participant.ageGroup == 'كبار'
                                            ? AppTheme.primaryColor
                                            : AppTheme.secondaryColor,
                                  ),
                                ),
                                child: Text(
                                  'فئة ${widget.participant.ageGroup}',
                                  style: AppTheme.labelMedium.copyWith(
                                    color:
                                        widget.participant.ageGroup == 'كبار'
                                            ? AppTheme.primaryColor
                                            : AppTheme.secondaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Informations personnelles détaillées
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المعلومات الشخصية',
                                style: AppTheme.labelLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              _buildInfoRow(
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

                              _buildInfoRow(
                                icon: Icons.phone,
                                label: 'رقم الهاتف',
                                value: widget.participant.phone,
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              _buildInfoRow(
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

                      // Informations القرآنية
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المعلومات القرآنية',
                                style: AppTheme.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              _buildInfoRow(
                                icon: Icons.menu_book,
                                label: 'كم حفظ من القرآن',
                                value: widget.participant.quranMemorized,
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              _buildInfoRow(
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

                      // الخبرة والمسابقات السابقة
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الخبرة والمسابقات السابقة',
                                style: AppTheme.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              _buildInfoRow(
                                icon:
                                    widget.participant.wonPreviousRanks
                                        ? Icons.emoji_events
                                        : Icons.emoji_events_outlined,
                                label: 'المراتب السابقة',
                                value:
                                    widget.participant.wonPreviousRanks
                                        ? 'حصل على مراتب 1 أو 2'
                                        : 'لم يحصل على مراتب',
                                valueColor:
                                    widget.participant.wonPreviousRanks
                                        ? AppTheme.warningColor
                                        : AppTheme.textSecondaryColor,
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              _buildInfoRow(
                                icon:
                                    widget.participant.participatedBefore
                                        ? Icons.history
                                        : Icons.history_outlined,
                                label: 'المشاركة السابقة',
                                value:
                                    widget.participant.participatedBefore
                                        ? 'شارك في نسخة سابقة'
                                        : 'لم يشارك من قبل',
                                valueColor:
                                    widget.participant.participatedBefore
                                        ? AppTheme.infoColor
                                        : AppTheme.textSecondaryColor,
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
                      const SizedBox(height: AppTheme.spacingS),

                      // Informations de la compétition
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'معلومات المسابقة',
                                style: AppTheme.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

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
                                icon:
                                    widget.participant.isAccepted == true
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                label: 'حالة المشاركة',
                                value:
                                    widget.participant.isAccepted == true
                                        ? 'مقبول'
                                        : 'غير مقبول',
                                valueColor:
                                    widget.participant.isAccepted == true
                                        ? AppTheme.successColor
                                        : AppTheme.errorColor,
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              _buildInfoRow(
                                icon:
                                    widget.participant.isEvaluated
                                        ? Icons.task_alt
                                        : Icons.pending,
                                label: 'حالة التقييم',
                                value:
                                    widget.participant.isEvaluated
                                        ? 'تم التقييم'
                                        : 'لم يتم التقييم',
                                valueColor:
                                    widget.participant.isEvaluated
                                        ? AppTheme.successColor
                                        : AppTheme.warningColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),

                      // Actions
                      SizedBox(
                        width: double.infinity,
                        child:
                            widget.participant.isAccepted == true
                                ? PrimaryButton(
                                  onPressed: _showRejectConfirmation,
                                  text: 'إلغاء المشاركة',
                                )
                                : PrimaryButton(
                                  onPressed: _acceptParticipant,
                                  text: 'قبول المشاركة',
                                ),
                      ),
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
    final confirmed = await ConfirmationService.showDeleteConfirmation(
      context,
      title: 'إلغاء المشاركة',
      message: 'هل أنت متأكد من إلغاء مشاركة ${widget.participant.fullName}؟',
      confirmText: 'إلغاء المشاركة',
    );

    if (confirmed == true) {
      await _rejectParticipant();
    }
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

  Future<void> _rejectParticipant() async {
    setState(() => _isLoading = true);

    try {
      await _participantService.updateParticipantAcceptance(
        widget.participant.id,
        false,
      );

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
      await _participantService.updateParticipantAcceptance(
        widget.participant.id,
        true,
      );

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

  int _calculateAge() {
    final now = DateTime.now();
    final birthDate = widget.participant.birthDate;
    int age = now.year - birthDate.year;

    // Ajuster si l'anniversaire n'a pas encore eu lieu cette année
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }
}
