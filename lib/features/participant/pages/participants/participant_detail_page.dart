import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/participant.dart';

class ParticipantDetailPage extends StatelessWidget {
  final Participant participant;

  const ParticipantDetailPage({super.key, required this.participant});

  bool get _isMale => participant.gender == 'ذكر';
  bool get _isAdult => participant.ageGroup == 'كبار';
  Color get _genderColor => _isMale ? AppTheme.infoColor : AppTheme.accentColor;

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  int _ageOn(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  String _orUnknown(String value) =>
      value.trim().isEmpty ? 'غير محدد' : value.trim();

  void _share() {
    final number = participant.registrationNumber?.toString() ?? 'غير محدد';
    SharePlus.instance.share(
      ShareParams(
        text:
            'المشارك: ${participant.fullName}\n'
            'رقم التسجيل: $number\n'
            'الفرع: ${_isAdult ? 'الكبار' : 'الصغار'}',
        subject: 'بطاقة مشارك',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // En-tête
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    final isAccepted = participant.isAccepted;
    final number = participant.registrationNumber?.toString() ?? 'غير محدد';

    return AppGradientHeader(
      leading: CircleAvatar(
        radius: 36,
        backgroundColor: Colors.white,
        child: Icon(
          _isMale ? Icons.male_rounded : Icons.female_rounded,
          size: 36,
          color: _genderColor,
        ),
      ),
      title: participant.fullName,
      badges: [
        AppHeaderBadge(
          icon: Icons.confirmation_number_rounded,
          text: 'رقم التسجيل $number',
          highlightColor: AppTheme.secondaryColor,
        ),
        AppHeaderBadge(
          icon: Icons.groups_rounded,
          text: _isAdult ? 'فئة الكبار' : 'فئة الصغار',
        ),
        AppHeaderBadge(
          icon: isAccepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
          text: isAccepted ? 'مقبول' : 'مرفوض',
          highlightColor: isAccepted ? null : AppTheme.errorColor,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sections d'informations
  // ---------------------------------------------------------------------------

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> rows,
  }) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) children.add(const Divider(height: 1));
      children.add(rows[i]);
    }

    return AppSection(
      icon: icon,
      color: color,
      title: title,
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondaryColor),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooleanRow(String label, bool value, IconData icon) {
    final color = value ? AppTheme.successColor : AppTheme.textDisabledColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondaryColor),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          AppTag(
            text: value ? 'نعم' : 'لا',
            color: color,
            icon:
                value
                    ? Icons.check_circle_rounded
                    : Icons.remove_circle_outline_rounded,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reason = participant.rejectionReason?.trim();

    return Scaffold(
      appBar: ModernAppBar(
        title: 'تفاصيل المشارك',
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'مشاركة',
            onPressed: _share,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!participant.isAccepted) ...[
                  AppNotice(
                    text:
                        'سبب الرفض: ${reason != null && reason.isNotEmpty ? reason : 'تم رفض المشارك بناءً على المعايير المحددة'}',
                    color: AppTheme.errorColor,
                    icon: Icons.info_rounded,
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                ],
                _buildSection(
                  title: 'المعلومات الشخصية',
                  icon: Icons.person_rounded,
                  color: AppTheme.primaryColor,
                  rows: [
                    _buildInfoRow(
                      'النوع',
                      _isMale ? 'ذكر' : 'أنثى',
                      _isMale ? Icons.male_rounded : Icons.female_rounded,
                    ),
                    _buildInfoRow(
                      'تاريخ الميلاد',
                      '${_formatDate(participant.birthDate)} '
                          '(${_ageOn(participant.birthDate)} سنة)',
                      Icons.cake_rounded,
                    ),
                    _buildInfoRow(
                      'الفئة العمرية',
                      _isAdult ? 'الكبار' : 'الصغار',
                      Icons.groups_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                _buildSection(
                  title: 'معلومات المشاركة',
                  icon: Icons.assignment_rounded,
                  color: AppTheme.secondaryColor,
                  rows: [
                    _buildInfoRow(
                      'مقدار الحفظ',
                      _orUnknown(participant.quranMemorized),
                      Icons.auto_stories_rounded,
                    ),
                    _buildInfoRow(
                      'عدد الروايات',
                      _orUnknown(participant.readingMethods),
                      Icons.menu_book_rounded,
                    ),
                    _buildBooleanRow(
                      'لديه إجازة',
                      participant.hasIjaza,
                      Icons.school_rounded,
                    ),
                    _buildBooleanRow(
                      'شارك في نسخة ماضية',
                      participant.participatedBefore,
                      Icons.history_rounded,
                    ),
                    _buildBooleanRow(
                      'فاز بمراتب سابقة',
                      participant.wonPreviousRanks,
                      Icons.emoji_events_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingL),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
