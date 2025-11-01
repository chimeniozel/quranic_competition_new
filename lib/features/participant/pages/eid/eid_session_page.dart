import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/eid_session_service.dart';
import 'package:quranic_competition/models/eid_session.dart';
import 'package:quranic_competition/models/eid_participant.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';

class EidSessionPage extends StatefulWidget {
  final EidSession session;

  const EidSessionPage({super.key, required this.session});

  @override
  State<EidSessionPage> createState() => _EidSessionPageState();
}

class _EidSessionPageState extends State<EidSessionPage> {
  final EidSessionService _service = EidSessionService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = false;
  bool _isRegistered = false;
  List<EidParticipant> _winners = [];
  bool _isLoadingWinners = false;

  @override
  void initState() {
    super.initState();
    _loadWinners();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadWinners() async {
    setState(() => _isLoadingWinners = true);
    try {
      final winners = await _service.getWinners(widget.session.id);
      if (mounted) {
        setState(() {
          _winners = winners;
          _isLoadingWinners = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingWinners = false);
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الجنس'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _service.registerParticipant(
        sessionId: widget.session.id,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        gender: _selectedGender!,
      );

      setState(() {
        _isRegistered = true;
        _isLoading = false;
      });

      // Recharger les gagnants après l'inscription
      await _loadWinners();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم التسجيل بنجاح! 🎉'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التسجيل: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(title: widget.session.name),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Affichage des gagnants - Toujours visible en haut
            if (_winners.isNotEmpty) ...[
              ModernCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: Colors.amber,
                            size: 24,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            '🎉 الفائزون 🎉',
                            style: AppTheme.headingSmall.copyWith(
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      if (_isLoadingWinners)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppTheme.spacingL),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        ...List.generate(_winners.length, (index) {
                          final winner = _winners[index];
                          return Container(
                            margin: const EdgeInsets.only(
                              bottom: AppTheme.spacingS,
                            ),
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.shade50,
                                  Colors.orange.shade50,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                              border: Border.all(
                                color: Colors.amber.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.amber.shade400,
                                        Colors.orange.shade400,
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: AppTheme.headingSmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Icon(
                                  winner.gender == 'ذكر'
                                      ? Icons.male
                                      : Icons.female,
                                  color:
                                      winner.gender == 'ذكر'
                                          ? Colors.blue
                                          : Colors.pink,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        winner.fullName,
                                        style: AppTheme.bodyMedium.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                      Text(
                                        winner.phone,
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.emoji_events,
                                  color: Colors.amber.shade700,
                                  size: 28,
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
            ],
            // Message de succès après inscription
            if (_isRegistered) ...[
              ModernCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingXL),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingL),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 80,
                          color: AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      Text(
                        '🎉 تم التسجيل بنجاح! 🎉',
                        style: AppTheme.headingMedium.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'شكراً لك على التسجيل في الفسحة أو الدورة "${widget.session.name}"',
                        style: AppTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      PrimaryButton(
                        onPressed: () {
                          _nameController.clear();
                          _phoneController.clear();
                          _selectedGender = null;
                          setState(() => _isRegistered = false);
                        },
                        text: 'تسجيل جديد',
                        icon: Icons.person_add,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
            ],
            // Formulaire d'inscription (seulement si l'inscription est ouverte)
            if (!_isRegistered && widget.session.isOpen)
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.session.description != null) ...[
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppTheme.infoColor,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'معلومات الفسحة أو الدورة',
                                    style: AppTheme.headingSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Text(
                                widget.session.description!,
                                style: AppTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                    ],
                    ModernCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('التسجيل', style: AppTheme.headingSmall),
                            const SizedBox(height: AppTheme.spacingS),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'الاسم الكامل *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                ),
                                prefixIcon: const Icon(Icons.person),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'يرجى إدخال الاسم';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'رقم الهاتف *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                ),
                                prefixIcon: const Icon(Icons.phone),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'يرجى إدخال رقم الهاتف';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            Text(
                              'الجنس *',
                              style: AppTheme.labelMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedGender = 'ذكر');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingS,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _selectedGender == 'ذكر'
                                                ? Colors.blue.withOpacity(0.1)
                                                : AppTheme.backgroundColor,
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusM,
                                        ),
                                        border: Border.all(
                                          color:
                                              _selectedGender == 'ذكر'
                                                  ? Colors.blue
                                                  : AppTheme.dividerColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.male,
                                            color:
                                                _selectedGender == 'ذكر'
                                                    ? Colors.blue
                                                    : AppTheme
                                                        .textSecondaryColor,
                                          ),
                                          const SizedBox(
                                            width: AppTheme.spacingS,
                                          ),
                                          Text(
                                            'ذكر',
                                            style: AppTheme.labelMedium
                                                .copyWith(
                                                  color:
                                                      _selectedGender == 'ذكر'
                                                          ? Colors.blue
                                                          : AppTheme
                                                              .textPrimaryColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedGender = 'أنثى');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingS,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _selectedGender == 'أنثى'
                                                ? Colors.pink.withOpacity(0.1)
                                                : AppTheme.backgroundColor,
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusM,
                                        ),
                                        border: Border.all(
                                          color:
                                              _selectedGender == 'أنثى'
                                                  ? Colors.pink
                                                  : AppTheme.dividerColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.female,
                                            color:
                                                _selectedGender == 'أنثى'
                                                    ? Colors.pink
                                                    : AppTheme
                                                        .textSecondaryColor,
                                          ),
                                          const SizedBox(
                                            width: AppTheme.spacingS,
                                          ),
                                          Text(
                                            'أنثى',
                                            style: AppTheme.labelMedium
                                                .copyWith(
                                                  color:
                                                      _selectedGender == 'أنثى'
                                                          ? Colors.pink
                                                          : AppTheme
                                                              .textPrimaryColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingL),
                            SizedBox(
                              width: double.infinity,
                              child: PrimaryButton(
                                onPressed: _isLoading ? null : _register,
                                text: _isLoading ? 'جاري التسجيل...' : 'تسجيل',
                                icon: _isLoading ? null : Icons.person_add,
                              ),
                            ),
                            if (!widget.session.isOpen) ...[
                              const SizedBox(height: AppTheme.spacingS),
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingS,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.errorColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.lock,
                                      color: AppTheme.errorColor,
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Expanded(
                                      child: Text(
                                        'التسجيل مغلق لهذه الفسحة أو الدورة',
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: AppTheme.errorColor,
                                          fontWeight: FontWeight.w600,
                                        ),
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
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
