import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/participant.dart';

class ParticipantDetailPage extends StatelessWidget {
  final Participant participant;

  const ParticipantDetailPage({super.key, required this.participant});

  bool get _isMale => participant.gender == 'ذكر';
  bool get _isAdult => participant.ageGroup == 'كبار';
  Color get _genderColor => _isMale ? AppTheme.infoColor : AppTheme.accentColor;
  Color get _groupColor => _isAdult ? AppTheme.infoColor : AppTheme.primaryColor;

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

  Widget _buildHeaderCard() {
    final isAccepted = participant.isAccepted;
    final statusColor = isAccepted ? AppTheme.successColor : AppTheme.errorColor;

    return ModernCard(
      margin: const EdgeInsets.all(AppTheme.spacingS),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: _genderColor.withOpacity(0.12),
              child: Icon(
                _isMale ? Icons.male_rounded : Icons.female_rounded,
                size: 36,
                color: _genderColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              participant.fullName,
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingS),

            // Numéro d'inscription, mis en avant
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.confirmation_number_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'رقم التسجيل: ${participant.registrationNumber?.toString() ?? 'غير محدد'}',
                    style: AppTheme.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppTheme.spacingS,
              runSpacing: AppTheme.spacingS,
              children: [
                _buildChip(
                  _isAdult ? 'فئة الكبار' : 'فئة الصغار',
                  Icons.people_rounded,
                  _groupColor,
                ),
                _buildChip(
                  isAccepted ? 'مقبول' : 'مرفوض',
                  isAccepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  statusColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: AppTheme.spacingXS),
          Text(
            text,
            style: AppTheme.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionCard() {
    final reason = participant.rejectionReason?.trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: AppTheme.errorColor, size: 20),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سبب الرفض',
                  style: AppTheme.labelLarge.copyWith(color: AppTheme.errorColor),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  reason != null && reason.isNotEmpty
                      ? reason
                      : 'تم رفض المشارك بناءً على المعايير المحددة',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.errorColor),
                ),
              ],
            ),
          ),
        ],
      ),
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

    return ModernCard(
      margin: const EdgeInsets.all(AppTheme.spacingS),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  title,
                  style: AppTheme.headingSmall.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            ...children,
          ],
        ),
      ),
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
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor),
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Flexible(
            child: Text(
              value,
              style: AppTheme.labelLarge.copyWith(color: AppTheme.primaryColor),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooleanRow(String label, bool value, IconData icon) {
    final color = value ? AppTheme.successColor : AppTheme.textSecondaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondaryColor),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor),
            ),
          ),
          Icon(
            value ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: AppTheme.spacingXS),
          Text(
            value ? 'نعم' : 'لا',
            style: AppTheme.labelLarge.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppTheme.spacingL),
        children: [
          _buildHeaderCard(),
          if (!participant.isAccepted) _buildRejectionCard(),

          _buildSection(
            title: 'المعلومات الشخصية',
            icon: Icons.person_outline_rounded,
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
                Icons.people_rounded,
              ),
            ],
          ),

          _buildSection(
            title: 'معلومات المشاركة',
            icon: Icons.assignment_rounded,
            color: AppTheme.warningColor,
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
        ],
      ),
    );
  }
}
