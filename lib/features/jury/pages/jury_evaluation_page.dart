import 'package:flutter/material.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/participant.dart';
import 'package:quranic_competition/models/note_model.dart';
import 'package:quranic_competition/models/evaluation.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';
import 'package:quranic_competition/core/services/round_service.dart';

class JuryEvaluationPage extends StatefulWidget {
  final Participant participant;
  final AppUser appUser;
  final CompetitionVersion version;

  const JuryEvaluationPage({
    super.key,
    required this.participant,
    required this.appUser,
    required this.version,
  });

  @override
  State<JuryEvaluationPage> createState() => _JuryEvaluationPageState();
}

class _JuryEvaluationPageState extends State<JuryEvaluationPage> {
  final _formKey = GlobalKey<FormState>();
  late NoteModel _noteModel;
  final _notesController = TextEditingController();
  final EvaluationService _evaluationService = EvaluationService();
  final RoundService _roundService = RoundService();

  Evaluation? _existingEvaluation;
  Round? _activeRound;
  bool _isSubmitting = false;
  bool _isLoading = true;
  double _totalScore = 0.0;

  @override
  void initState() {
    super.initState();
    _noteModel = NoteModel();
    _loadActiveRoundAndEvaluation();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveRoundAndEvaluation() async {
    try {
      final round = await _roundService.getActiveRound(widget.version.id);
      if (round == null) throw Exception('لا يوجد جولة نشطة حالياً');

      setState(() => _activeRound = round);

      final eval = await _evaluationService.getEvaluationByJuryAndParticipant(
        juryId: widget.appUser.id,
        participantId: widget.participant.id,
        roundId: round.id,
        versionId: widget.version.id,
        ageGroup: widget.participant.ageGroup,
      );

      if (eval != null) {
        _existingEvaluation = eval;
        _notesController.text = eval.notes ?? '';
        _noteModel.result = eval.totalScore;

        _noteModel
          ..noteTajwid = eval.noteModel.noteTajwid
          ..noteHousnSawtt = eval.noteModel.noteHousnSawtt;

        if (widget.participant.ageGroup == 'كبار') {
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

    if (widget.participant.ageGroup == 'كبار') {
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
    if (!_formKey.currentState!.validate() || _activeRound == null) return;

    setState(() => _isSubmitting = true);

    final evaluation = Evaluation(
      id: _existingEvaluation?.id ?? '',
      participantId: widget.participant.id,
      juryId: widget.appUser.id,
      versionId: widget.version.id,
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
          widget.participant.ageGroup,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إرسال التقييم بنجاح')));
      } else {
        await _evaluationService.updateEvaluation(
          evaluation,
          widget.participant.ageGroup,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label (الحد الأقصى: $max)'),
        Slider(
          min: 0,
          max: max,
          divisions: max.toInt(),
          label: _getValueForLabel(label).toStringAsFixed(1),
          value: _getValueForLabel(label),
          onChanged: (value) {
            onChanged(value);
            _recalculateTotal();
          },
        ),
      ],
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
    final isAdult = widget.participant.ageGroup == 'كبار';

    return Scaffold(
      appBar: AppBar(title: Text('تصحيح: ${widget.participant.fullName}')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _activeRound == null
              ? const Center(child: Text('لا يوجد جولة نشطة حالياً'))
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
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
                      const SizedBox(height: 16),
                      Text(
                        'النتيجة النهائية: ${_totalScore.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      _isSubmitting
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                            onPressed: _submit,
                            child: Text(
                              _existingEvaluation == null
                                  ? 'إرسال التقييم'
                                  : 'تحديث التقييم',
                            ),
                          ),
                    ],
                  ),
                ),
              ),
    );
  }
}
