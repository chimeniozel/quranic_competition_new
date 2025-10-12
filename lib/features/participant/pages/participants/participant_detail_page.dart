import 'package:flutter/material.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/participant.dart';

class ParticipantDetailPage extends StatelessWidget {
  final Participant participant;

  const ParticipantDetailPage({super.key, required this.participant});

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return ModernCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.08), color.withOpacity(0.03)],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.labelMedium),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      value,
                      style: AppTheme.labelLarge.copyWith(
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
    );
  }

  Widget _buildBooleanInfoCard(
    String title,
    bool? value,
    IconData icon,
    Color color,
  ) {
    final displayValue =
        value == null
            ? 'غير محدد'
            : value
            ? 'نعم'
            : 'لا';

    final displayColor =
        value == null
            ? Colors.grey
            : value
            ? Colors.green
            : Colors.red;

    final statusIcon =
        value == null
            ? Icons.help_outline
            : value
            ? Icons.check_circle
            : Icons.cancel;

    return ModernCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.08), color.withOpacity(0.03)],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.labelMedium),
                    const SizedBox(height: AppTheme.spacingXS),
                    Row(
                      children: [
                        Icon(statusIcon, color: displayColor, size: 16),
                        const SizedBox(width: AppTheme.spacingS),
                        Text(
                          displayValue,
                          style: AppTheme.labelLarge.copyWith(
                            color: displayColor,
                          ),
                        ),
                      ],
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

  Widget _buildStatusCard() {
    final isAccepted = participant.isAccepted;
    final statusColor =
        isAccepted == true
            ? Colors.green
            : isAccepted == false
            ? Colors.red
            : Colors.orange;

    final statusText =
        isAccepted == true
            ? 'مقبول'
            : isAccepted == false
            ? 'مرفوض'
            : 'قيد المراجعة';

    final statusIcon =
        isAccepted == true
            ? Icons.check_circle
            : isAccepted == false
            ? Icons.cancel
            : Icons.hourglass_empty;

    return ModernCard(
      margin: const EdgeInsets.all(AppTheme.spacingM),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusColor.withOpacity(0.1),
              statusColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            children: [
              // Statut principal
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('حالة القبول', style: AppTheme.labelMedium),
                          const SizedBox(height: AppTheme.spacingXS),
                          Text(
                            statusText,
                            style: AppTheme.headingSmall.copyWith(
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Raison de refus si applicable
              if (isAccepted == false) ...[
                const SizedBox(height: AppTheme.spacingM),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.info,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            'سبب الرفض',
                            style: AppTheme.labelLarge.copyWith(
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        participant.rejectionReason != null &&
                                participant.rejectionReason!.isNotEmpty
                            ? participant.rejectionReason!
                            : 'تم رفض المشارك بناءً على المعايير المحددة',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return ModernCard(
      margin: const EdgeInsets.all(AppTheme.spacingM),
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
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
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
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor:
                      participant.gender == 'ذكر'
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.pink.withOpacity(0.1),
                  child: Icon(
                    participant.gender == 'ذكر' ? Icons.male : Icons.female,
                    size: 28,
                    color:
                        participant.gender == 'ذكر' ? Colors.blue : Colors.pink,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Nom complet
              Text(
                participant.fullName,
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
                      participant.ageGroup == 'كبار'
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color:
                        participant.ageGroup == 'كبار'
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
                          participant.ageGroup == 'كبار'
                              ? Colors.blue
                              : Colors.purple,
                      size: 16,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      participant.ageGroup == 'كبار'
                          ? 'فئة الكبار'
                          : 'فئة الصغار',
                      style: AppTheme.labelLarge.copyWith(
                        color:
                            participant.ageGroup == 'كبار'
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
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(color: AppTheme.dividerColor),
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
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.confirmation_number,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Text('رقم التسجيل', style: AppTheme.labelMedium),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      participant.registrationNumber?.toString() ?? 'غير محدد',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    print(
      '📱 ParticipantDetailPage build - Participant: ${participant.fullName}',
    );
    return Scaffold(
      appBar: ModernAppBar(
        title: 'تفاصيل المشارك',
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'مشاركة',
            onPressed: () {
              // TODO: Implémenter le partage
            },
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Carte d'en-tête
          SliverToBoxAdapter(child: _buildHeaderCard()),

          // Carte de statut
          SliverToBoxAdapter(child: _buildStatusCard()),

          // Section informations personnelles
          SliverToBoxAdapter(
            child: Container(
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
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 16,
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
          ),

          // Cartes d'informations personnelles
          SliverToBoxAdapter(
            child: _buildInfoCard(
              'النوع',
              participant.gender == 'ذكر' ? 'ذكر' : 'أنثى',
              participant.gender == 'ذكر' ? Icons.male : Icons.female,
              participant.gender == 'ذكر' ? Colors.blue : Colors.pink,
            ),
          ),

          SliverToBoxAdapter(
            child: _buildInfoCard(
              'تاريخ الميلاد',
              '${participant.birthDate.day}/${participant.birthDate.month}/${participant.birthDate.year}',
              Icons.cake,
              Colors.orange,
            ),
          ),

          SliverToBoxAdapter(
            child: _buildInfoCard(
              'الفئة العمرية',
              participant.ageGroup == 'كبار' ? 'الكبار' : 'الصغار',
              Icons.people,
              participant.ageGroup == 'كبار' ? Colors.green : Colors.purple,
            ),
          ),

          // Section informations de participation
          SliverToBoxAdapter(
            child: Container(
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
                    Colors.orange.withOpacity(0.1),
                    Colors.orange.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Text(
                    'معلومات المشاركة',
                    style: AppTheme.headingSmall.copyWith(
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cartes d'informations de participation
          SliverToBoxAdapter(
            child: _buildBooleanInfoCard(
              'هل شارك في نسخة ماضية؟',
              participant.participatedBefore,
              Icons.history,
              Colors.blue,
            ),
          ),

          SliverToBoxAdapter(
            child: _buildBooleanInfoCard(
              'هل لديه إجازة؟',
              participant.hasIjaza,
              Icons.school,
              Colors.purple,
            ),
          ),

          SliverToBoxAdapter(
            child: _buildInfoCard(
              'عدد الروايات',
              participant.readingMethods == 'رواية واحدة'
                  ? 'رواية واحدة'
                  : participant.readingMethods == 'أكثر من رواية'
                  ? 'أكثر من رواية'
                  : 'غير محدد',
              Icons.menu_book,
              Colors.teal,
            ),
          ),

          SliverToBoxAdapter(
            child: _buildBooleanInfoCard(
              'هل فاز بمراتب سابقة؟',
              participant.wonPreviousRanks,
              Icons.emoji_events,
              Colors.amber,
            ),
          ),

          // Espace en bas
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingL)),
        ],
      ),
    );
  }
}
