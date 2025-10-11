import 'package:flutter/material.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';

/// Page de démonstration des nouveaux composants UI
class UIShowcasePage extends StatefulWidget {
  const UIShowcasePage({super.key});

  @override
  State<UIShowcasePage> createState() => _UIShowcasePageState();
}

class _UIShowcasePageState extends State<UIShowcasePage> {
  bool _isLoading = false;
  double _progressValue = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'عرض المكونات الحديثة'),
      body: ModernPullToRefresh(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Boutons
              _buildSection(
                title: 'الأزرار',
                child: Column(
                  children: [
                    const PrimaryButton(text: 'زر أساسي', icon: Icons.star),
                    const SizedBox(height: AppTheme.spacingM),
                    const PrimaryButton(
                      text: 'زر أساسي مع تحميل',
                      isLoading: true,
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    const SecondaryButton(text: 'زر ثانوي', icon: Icons.edit),
                    const SizedBox(height: AppTheme.spacingM),
                    const SecondaryButton(
                      text: 'زر ثانوي مع تحميل',
                      isLoading: true,
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    PrimaryButton(
                      text: 'زر كامل العرض',
                      fullWidth: true,
                      onPressed: () {
                        setState(() {
                          _isLoading = !_isLoading;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Section Cards
              _buildSection(
                title: 'البطاقات',
                child: Column(
                  children: [
                    const ModernCard(child: Text('بطاقة بسيطة')),
                    const ModernCard(
                      backgroundColor: Colors.blue,
                      child: Text(
                        'بطاقة ملونة',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    ModernCard(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم النقر على البطاقة')),
                        );
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.touch_app),
                          SizedBox(width: AppTheme.spacingM),
                          Text('بطاقة قابلة للنقر'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Section Badges
              _buildSection(
                title: 'الشارات',
                child: Wrap(
                  spacing: AppTheme.spacingM,
                  runSpacing: AppTheme.spacingM,
                  children: const [
                    StatusBadge(text: 'نشط', status: 'active'),
                    StatusBadge(text: 'في الانتظار', status: 'pending'),
                    StatusBadge(text: 'معطل', status: 'inactive'),
                    StatusBadge(text: 'موثق', status: 'verified'),
                    StatusBadge(text: 'غير موثق', status: 'unverified'),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Section Avatars
              _buildSection(
                title: 'الصور الرمزية',
                child: Row(
                  children: const [
                    CustomAvatar(initials: 'أح'),
                    SizedBox(width: AppTheme.spacingM),
                    CustomAvatar(initials: 'مح'),
                    SizedBox(width: AppTheme.spacingM),
                    CustomAvatar(initials: 'سع'),
                    SizedBox(width: AppTheme.spacingM),
                    CustomAvatar(fallbackIcon: Icons.person),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Section Champs de Saisie
              _buildSection(
                title: 'حقول الإدخال',
                child: Column(
                  children: const [
                    ModernTextField(
                      label: 'اسم المستخدم',
                      hint: 'أدخل اسم المستخدم',
                      prefixIcon: Icon(Icons.person),
                    ),
                    SizedBox(height: AppTheme.spacingM),
                    ModernTextField(
                      label: 'البريد الإلكتروني',
                      hint: 'أدخل البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: AppTheme.spacingM),
                    ModernTextField(
                      label: 'كلمة المرور',
                      hint: 'أدخل كلمة المرور',
                      prefixIcon: Icon(Icons.lock),
                      suffixIcon: Icon(Icons.visibility),
                      obscureText: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Section Indicateurs de Progression
              _buildSection(
                title: 'مؤشرات التقدم',
                child: Column(
                  children: [
                    ModernProgressIndicator(
                      value: _progressValue,
                      label: 'تقدم المهمة',
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            text: 'تقدم',
                            onPressed: () {
                              setState(() {
                                _progressValue = (_progressValue + 0.1).clamp(
                                  0.0,
                                  1.0,
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: SecondaryButton(
                            text: 'تراجع',
                            onPressed: () {
                              setState(() {
                                _progressValue = (_progressValue - 0.1).clamp(
                                  0.0,
                                  1.0,
                                );
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Section Alertes
              _buildSection(
                title: 'التنبيهات',
                child: Column(
                  children: const [
                    ModernAlert(message: 'هذه رسالة معلوماتية', type: 'info'),
                    SizedBox(height: AppTheme.spacingM),
                    ModernAlert(
                      message: 'تم حفظ البيانات بنجاح',
                      type: 'success',
                    ),
                    SizedBox(height: AppTheme.spacingM),
                    ModernAlert(
                      message: 'تحذير: تأكد من البيانات',
                      type: 'warning',
                    ),
                    SizedBox(height: AppTheme.spacingM),
                    ModernAlert(
                      message: 'خطأ: فشل في حفظ البيانات',
                      type: 'error',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Section États de Chargement
              _buildSection(
                title: 'حالات التحميل',
                child: Column(
                  children: [
                    const ModernLoadingIndicator(message: 'جاري التحميل...'),
                    const SizedBox(height: AppTheme.spacingL),
                    const LoadingSkeleton(width: double.infinity, height: 60),
                    const SizedBox(height: AppTheme.spacingM),
                    const Row(
                      children: [
                        LoadingSkeleton(width: 50, height: 50),
                        SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LoadingSkeleton(
                                width: double.infinity,
                                height: 16,
                              ),
                              SizedBox(height: AppTheme.spacingS),
                              LoadingSkeleton(width: 200, height: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Section États Spéciaux
              _buildSection(
                title: 'الحالات الخاصة',
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('حالة فارغة'),
                                content: const EmptyState(
                                  title: 'لا توجد بيانات',
                                  subtitle: 'لم يتم العثور على أي عناصر للعرض',
                                  icon: Icons.inbox_outlined,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('إغلاق'),
                                  ),
                                ],
                              ),
                        );
                      },
                      child: const Text('عرض حالة فارغة'),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('حالة خطأ'),
                                content: ErrorState(
                                  title: 'حدث خطأ',
                                  subtitle: 'فشل في تحميل البيانات',
                                  onRetry: () {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('تم إعادة المحاولة'),
                                      ),
                                    );
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('إغلاق'),
                                  ),
                                ],
                              ),
                        );
                      },
                      child: const Text('عرض حالة خطأ'),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('حالة نجاح'),
                                content: const SuccessState(
                                  title: 'تم بنجاح',
                                  subtitle: 'تم حفظ البيانات بنجاح',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('إغلاق'),
                                  ),
                                ],
                              ),
                        );
                      },
                      child: const Text('عرض حالة نجاح'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXXL),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.headingMedium),
        const SizedBox(height: AppTheme.spacingM),
        child,
      ],
    );
  }
}
