import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Un contrôleur de saisie par critère, pour permettre de taper une note
  // décimale (8.5, 9,5...) en plus du curseur.
  final Map<String, TextEditingController> _scoreControllers = {};
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
    for (final controller in _scoreControllers.values) {
      controller.dispose();
    }
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

        _syncScoreControllers();
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

    // Vérifier que toutes les notes sont remplies
    final isAdult = widget.args.participant.ageGroup == 'كبار';
    bool allNotesFilled = false;

    if (isAdult) {
      allNotesFilled =
          _noteModel.noteTajwid != null &&
          _noteModel.noteHousnSawtt != null &&
          _noteModel.noteOu4oubetSawtt != null &&
          _noteModel.noteWaqfAndIbtidaa != null;
    } else {
      allNotesFilled =
          _noteModel.noteTajwid != null &&
          _noteModel.noteHousnSawtt != null &&
          _noteModel.noteIltizamRiwaya != null;
    }

    if (!allNotesFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى ملء جميع الحقول المطلوبة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      print('❌ Erreur lors de la soumission de l\'évaluation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء إرسال التقييم: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Affiche une note : saisie directe (décimales autorisées : 8.5 / 8,5)
  /// et curseur par pas de 0.5 pour un réglage rapide.
  Widget _buildScoreInput(
    String label,
    double max,
    void Function(double) onChanged,
  ) {
    // Désactiver si l'évaluation n'est pas autorisée OU en mode lecture seule
    final isDisabled =
        !widget.args.version.juryEvaluationEnabled || _isReadOnly;
    final currentValue = _getValueForLabel(label);
    final controller = _controllerForLabel(label);

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              SizedBox(
                width: 110,
                child: TextFormField(
                  controller: controller,
                  enabled: !isDisabled,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    // Chiffres avec au plus un séparateur décimal (point ou
                    // virgule) et deux décimales : 8 / 8.5 / 8,5 / 8,75
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.isEmpty) return newValue;
                      return RegExp(
                            r'^\d{0,3}([.,]\d{0,2})?$',
                          ).hasMatch(newValue.text)
                          ? newValue
                          : oldValue;
                    }),
                  ],
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: '/ ${_formatScore(max)}',
                    suffixStyle: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingXS,
                      vertical: AppTheme.spacingXS,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                  ),
                  onChanged:
                      (text) => _onScoreTyped(text, max, controller, onChanged),
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
              // Pas de 0.5 pour permettre les demi-points (8.5, 9.5...)
              divisions: (max * 2).toInt(),
              label: _formatScore(currentValue),
              value: currentValue.clamp(0, max).toDouble(),
              onChanged:
                  isDisabled
                      ? null
                      : (value) {
                        onChanged(value);
                        _setControllerText(controller, value);
                        _recalculateTotal();
                      },
            ),
          ),
        ],
      ),
    );
  }

  TextEditingController _controllerForLabel(String label) {
    return _scoreControllers.putIfAbsent(
      label,
      () => TextEditingController(text: _formatScore(_getValueForLabel(label))),
    );
  }

  /// Recopie les notes du modèle dans les champs de saisie (après chargement
  /// d'une évaluation existante).
  void _syncScoreControllers() {
    for (final entry in _scoreControllers.entries) {
      _setControllerText(entry.value, _getValueForLabel(entry.key));
    }
  }

  void _setControllerText(TextEditingController controller, double value) {
    final text = _formatScore(value);
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Note saisie au clavier : la virgule est acceptée comme séparateur
  /// décimal, et la valeur est bornée par la note maximale du critère.
  void _onScoreTyped(
    String text,
    double max,
    TextEditingController controller,
    void Function(double) onChanged,
  ) {
    final normalized = text.trim().replaceAll(',', '.');

    if (normalized.isEmpty) {
      onChanged(0);
      _recalculateTotal();
      return;
    }

    final value = double.tryParse(normalized);
    if (value == null) return; // saisie encore incomplète, on attend la suite

    if (value > max) {
      // On ramène à la note maximale du critère et on corrige le champ
      onChanged(max);
      _setControllerText(controller, max);
      _recalculateTotal();
      return;
    }

    onChanged(value < 0 ? 0 : value);
    _recalculateTotal();
  }

  String _formatScore(double value) {
    final rounded = (value * 100).round() / 100;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
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
                padding: const EdgeInsets.all(AppTheme.spacingS),
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
                              const SizedBox(width: AppTheme.spacingS),
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
                              const SizedBox(width: AppTheme.spacingS),
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
                      _buildScoreInput(
                        'التجويد',
                        isAdult ? 70 : 15,
                        (v) => _noteModel.noteTajwid = v,
                      ),
                      _buildScoreInput(
                        'حسن الصوت',
                        isAdult ? 5 : 3,
                        (v) => _noteModel.noteHousnSawtt = v,
                      ),
                      if (isAdult) ...[
                        _buildScoreInput(
                          'عذوبة الصوت',
                          5,
                          (v) => _noteModel.noteOu4oubetSawtt = v,
                        ),
                        _buildScoreInput(
                          'الوقف والإبتداء',
                          20,
                          (v) => _noteModel.noteWaqfAndIbtidaa = v,
                        ),
                      ] else
                        _buildScoreInput(
                          'الإلتزام بالرواية',
                          2,
                          (v) => _noteModel.noteIltizamRiwaya = v,
                        ),
                      const SizedBox(height: AppTheme.spacingS),

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
                            const SizedBox(width: AppTheme.spacingS),
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
                      const SizedBox(height: AppTheme.spacingS),

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
                      const SizedBox(height: AppTheme.spacingS),

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
                                        AppTheme.spacingS,
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
                                          SizedBox(width: AppTheme.spacingS),
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
                              const SizedBox(width: AppTheme.spacingS),
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
                              const SizedBox(width: AppTheme.spacingS),
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
