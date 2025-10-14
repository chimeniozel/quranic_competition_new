import 'package:flutter/material.dart';
import 'package:quranic_competition/models/note_model.dart';
import 'package:quranic_competition/models/evaluation.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:quranic_competition/models/jury_evaluation_args.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';

class JuryEvaluationPage extends StatefulWidget {
  final JuryEvaluationArgs args;

  const JuryEvaluationPage({super.key, required this.args});

  @override
  State<JuryEvaluationPage> createState() => _JuryEvaluationPageState();
}

class _JuryEvaluationPageState extends State<JuryEvaluationPage> {
  final _formKey = GlobalKey<FormState>();
  late NoteModel _noteModel;
  final _notesController = TextEditingController();
  final EvaluationService _evaluationService = EvaluationService();

  Evaluation? _existingEvaluation;
  Round? _activeRound;
  bool _isSubmitting = false;
  bool _isLoading = true;
  double _totalScore = 0.0;
  bool _isReadOnly = false;

  @override
  void initState() {
    super.initState();
    _noteModel = NoteModel();
    _isReadOnly = widget.args.isReadOnly;
    _activeRound = widget.args.round;
    _loadEvaluation();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadEvaluation() async {
    try {
      if (_activeRound == null) throw Exception('لا يوجد جولة محددة');

      final eval = await _evaluationService.getEvaluationByJuryAndParticipant(
        juryId: widget.args.appUser.id,
        participantId: widget.args.participant.id,
        roundId: _activeRound!.id,
        versionId: widget.args.version.id,
        ageGroup: widget.args.participant.ageGroup,
      );

      if (eval != null) {
        _existingEvaluation = eval;
        _notesController.text = eval.notes ?? '';
        _noteModel.result = eval.totalScore;

        _noteModel
          ..noteTajwid = eval.noteModel.noteTajwid
          ..noteHousnSawtt = eval.noteModel.noteHousnSawtt;

        if (widget.args.participant.ageGroup == 'كبار') {
          _noteModel
            ..noteOu4oubetSawtt = eval.noteModel.noteOu4oubetSawtt
            ..noteWaqfAndIbtidaa = eval.noteModel.noteWaqfAndIbtidaa;
        } else {
          _noteModel.noteIltizamRiwaya = eval.noteModel.noteIltizamRiwaya;
        }

        _recalculateTotal();
      }
    } catch (e) {
      print('Erreur : $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _recalculateTotal() {
    final notes = <double>[];

    if (_noteModel.noteTajwid != null) notes.add(_noteModel.noteTajwid!);
    if (_noteModel.noteHousnSawtt != null) {
      notes.add(_noteModel.noteHousnSawtt!);
    }

    if (widget.args.participant.ageGroup == 'كبار') {
      if (_noteModel.noteOu4oubetSawtt != null) {
        notes.add(_noteModel.noteOu4oubetSawtt!);
      }
      if (_noteModel.noteWaqfAndIbtidaa != null) {
        notes.add(_noteModel.noteWaqfAndIbtidaa!);
      }
    } else {
      if (_noteModel.noteIltizamRiwaya != null) {
        notes.add(_noteModel.noteIltizamRiwaya!);
      }
    }

    final total = notes.isEmpty ? 0.0 : notes.reduce((a, b) => a + b);
    setState(() {
      _totalScore = total;
      _noteModel.result = total;
    });
  }

  Future<void> _submit() async {
    // Vérifier si l'évaluation est autorisée
    if (!widget.args.version.juryEvaluationEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.block, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'التقييم غير مسموح به - يرجى انتظار إذن المسؤول',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نشر النتائج - لا يمكن تعديل التقييم')),
      );
      return;
    }

    if (!_formKey.currentState!.validate() || _activeRound == null) return;

    setState(() => _isSubmitting = true);

    final evaluation = Evaluation(
      id: _existingEvaluation?.id ?? '',
      participantId: widget.args.participant.id,
      juryId: widget.args.appUser.id,
      versionId: widget.args.version.id,
      roundId: _activeRound!.id,
      totalScore: _totalScore,
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      submittedAt: DateTime.now(),
      noteModel: _noteModel,
    );

    try {
      if (_existingEvaluation == null) {
        await _evaluationService.submitEvaluation(
          evaluation,
          widget.args.participant.ageGroup,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إرسال التقييم بنجاح')));
      } else {
        await _evaluationService.updateEvaluation(
          evaluation,
          widget.args.participant.ageGroup,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تعديل التقييم بنجاح')));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ أثناء إرسال التقييم: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildSlider(
    String label,
    double max,
    void Function(double) onChanged,
  ) {
    // Désactiver si l'évaluation n'est pas autorisée OU en mode lecture seule
    final isDisabled =
        !widget.args.version.juryEvaluationEnabled || _isReadOnly;
    final currentValue = _getValueForLabel(label);

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTheme.labelLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingS,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Text(
                  '${currentValue.toStringAsFixed(1)} / $max',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor:
                  isDisabled
                      ? AppTheme.textDisabledColor
                      : AppTheme.primaryColor,
              inactiveTrackColor: AppTheme.dividerColor,
              thumbColor:
                  isDisabled
                      ? AppTheme.textDisabledColor
                      : AppTheme.primaryColor,
              overlayColor: AppTheme.primaryColor.withOpacity(0.2),
              valueIndicatorColor: AppTheme.primaryColor,
            ),
            child: Slider(
              min: 0,
              max: max,
              divisions: max.toInt(),
              label: currentValue.toStringAsFixed(1),
              value: currentValue,
              onChanged:
                  isDisabled
                      ? null
                      : (value) {
                        onChanged(value);
                        _recalculateTotal();
                      },
            ),
          ),
        ],
      ),
    );
  }

  double _getValueForLabel(String label) {
    switch (label) {
      case 'التجويد':
        return _noteModel.noteTajwid ?? 0;
      case 'حسن الصوت':
        return _noteModel.noteHousnSawtt ?? 0;
      case 'عذوبة الصوت':
        return _noteModel.noteOu4oubetSawtt ?? 0;
      case 'الوقف والإبتداء':
        return _noteModel.noteWaqfAndIbtidaa ?? 0;
      case 'الإلتزام بالرواية':
        return _noteModel.noteIltizamRiwaya ?? 0;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdult = widget.args.participant.ageGroup == 'كبار';

    return Scaffold(
      appBar: ModernAppBar(
        title:
            'تقييم المشارك رقم ${widget.args.participant.registrationNumber}',
      ),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : _activeRound == null
              ? const EmptyState(
                icon: Icons.event_busy,
                title: 'لا يوجد جولة محددة',
                subtitle: 'تأكد من وجود جولة نشطة للتقييم',
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Message d'avertissement si l'évaluation n'est pas autorisée
                      if (!widget.args.version.juryEvaluationEnabled)
                        ModernCard(
                          backgroundColor: AppTheme.errorColor.withOpacity(0.1),
                          child: Row(
                            children: [
                              Icon(
                                Icons.block,
                                color: AppTheme.errorColor,
                                size: 24,
                              ),
                              const SizedBox(width: AppTheme.spacingM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'التقييم غير مسموح به',
                                      style: AppTheme.headingSmall.copyWith(
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                    const SizedBox(height: AppTheme.spacingXS),
                                    Text(
                                      'لا يمكنك إرسال أو تعديل التقييم حالياً',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Message d'information pour le mode lecture seule
                      if (_isReadOnly &&
                          widget.args.version.juryEvaluationEnabled)
                        ModernCard(
                          backgroundColor: AppTheme.infoColor.withOpacity(0.1),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info,
                                color: AppTheme.infoColor,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.spacingM),
                              Expanded(
                                child: Text(
                                  'تم نشر النتائج - يمكنك عرض التقييم فقط',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.infoColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _buildSlider(
                        'التجويد',
                        isAdult ? 70 : 15,
                        (v) => _noteModel.noteTajwid = v,
                      ),
                      _buildSlider(
                        'حسن الصوت',
                        isAdult ? 5 : 3,
                        (v) => _noteModel.noteHousnSawtt = v,
                      ),
                      if (isAdult) ...[
                        _buildSlider(
                          'عذوبة الصوت',
                          5,
                          (v) => _noteModel.noteOu4oubetSawtt = v,
                        ),
                        _buildSlider(
                          'الوقف والإبتداء',
                          20,
                          (v) => _noteModel.noteWaqfAndIbtidaa = v,
                        ),
                      ] else
                        _buildSlider(
                          'الإلتزام بالرواية',
                          2,
                          (v) => _noteModel.noteIltizamRiwaya = v,
                        ),
                      const SizedBox(height: AppTheme.spacingM),

                      // Carte de résultat total
                      ModernCard(
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.star,
                              color: AppTheme.primaryColor,
                              size: 28,
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Text(
                              'النتيجة النهائية:',
                              style: AppTheme.headingSmall.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Text(
                              _totalScore.toStringAsFixed(2),
                              style: AppTheme.headingMedium.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),

                      // Champ de notes
                      ModernCard(
                        child: TextFormField(
                          controller: _notesController,
                          enabled:
                              !_isReadOnly &&
                              widget.args.version.juryEvaluationEnabled,
                          decoration: InputDecoration(
                            labelText: 'ملاحظات (اختياري)',
                            hintText: 'أضف ملاحظاتك هنا...',
                            border: InputBorder.none,
                            filled: false,
                            prefixIcon: Icon(
                              Icons.note_alt,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          style: AppTheme.bodyMedium,
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),

                      // Bouton de soumission (seulement si autorisé et pas en lecture seule)
                      if (!_isReadOnly &&
                          widget.args.version.juryEvaluationEnabled) ...[
                        SizedBox(
                          width: double.infinity,
                          child:
                              _isSubmitting
                                  ? ModernCard(
                                    backgroundColor: AppTheme.primaryColor
                                        .withOpacity(0.1),
                                    child: const Padding(
                                      padding: EdgeInsets.all(
                                        AppTheme.spacingM,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: AppTheme.spacingM),
                                          Text('جاري الإرسال...'),
                                        ],
                                      ),
                                    ),
                                  )
                                  : PrimaryButton(
                                    text:
                                        _existingEvaluation == null
                                            ? 'إرسال التقييم'
                                            : 'تحديث التقييم',
                                    icon:
                                        _existingEvaluation == null
                                            ? Icons.send
                                            : Icons.update,
                                    onPressed: _submit,
                                  ),
                        ),
                      ] else if (!widget
                          .args
                          .version
                          .juryEvaluationEnabled) ...[
                        // Message de blocage si l'évaluation n'est pas autorisée
                        ModernCard(
                          backgroundColor: AppTheme.errorColor.withOpacity(0.1),
                          child: Row(
                            children: [
                              Icon(
                                Icons.block,
                                color: AppTheme.errorColor,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.spacingM),
                              Expanded(
                                child: Text(
                                  'التقييم غير مسموح به - انتظر إذن المسؤول',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.errorColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_isReadOnly) ...[
                        // Message de lecture seule
                        ModernCard(
                          backgroundColor: AppTheme.textSecondaryColor
                              .withOpacity(0.1),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock,
                                color: AppTheme.textSecondaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.spacingM),
                              Expanded(
                                child: Text(
                                  'تم نشر النتائج - لا يمكن تعديل التقييم',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                    fontWeight: FontWeight.w500,
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
    );
  }
}
