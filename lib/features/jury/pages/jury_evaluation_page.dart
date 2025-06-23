import 'package:flutter/material.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/participant.dart';
import 'package:quranic_competition/models/note_model.dart';
import 'package:quranic_competition/models/evaluation.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart'; // À créer si ce n'est pas fait

class JuryEvaluationPage extends StatefulWidget {
  final Participant participant;
  final AppUser appUser;
  final int round;
  final CompetitionVersion version;

  const JuryEvaluationPage({
    super.key,
    required this.participant,
    required this.appUser,
    required this.round,
    required this.version,
  });

  @override
  State<JuryEvaluationPage> createState() => _JuryEvaluationPageState();
}

class _JuryEvaluationPageState extends State<JuryEvaluationPage> {
  final _formKey = GlobalKey<FormState>();
  final _noteModel = NoteModel();
  final _notesController = TextEditingController();
  final EvaluationService _evaluationService = EvaluationService();

  Evaluation? _existingEvaluation;
  bool _isSubmitting = false;
  bool _isLoading = true;
  double _totalScore = 0.0;

  @override
  void initState() {
    super.initState();
    _loadExistingEvaluation();
  }

  Future<void> _loadExistingEvaluation() async {
    try {
      final eval = await _evaluationService.getEvaluationByJuryAndParticipant(
        juryId: widget.appUser.id,
        participantId: widget.participant.id,
        round: widget.round,
        versionId: widget.version.id, ageGroup: widget.participant.ageGroup,
      );

      if (eval != null) {
        _existingEvaluation = eval;
        _notesController.text = eval.notes ?? '';
        _noteModel.result = eval.totalScore;

        if (widget.participant.ageGroup == 'كبار') {
          _noteModel
            ..noteTajwid = eval.noteModel.noteTajwid
            ..noteHousnSawtt = eval.noteModel.noteHousnSawtt
            ..noteOu4oubetSawtt = eval.noteModel.noteOu4oubetSawtt
            ..noteWaqfAndIbtidaa = eval.noteModel.noteWaqfAndIbtidaa
            ..noteIltizamRiwaya = eval.noteModel.noteIltizamRiwaya;
        } else {
          _noteModel
            ..noteTajwid = eval.noteModel.noteTajwid
            ..noteHousnSawtt = eval.noteModel.noteHousnSawtt
            ..noteIltizamRiwaya = eval.noteModel.noteIltizamRiwaya;
        }

        _recalculateTotal();
      }
    } catch (e) {
      print('Erreur lors du chargement de l’évaluation : $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _recalculateTotal() {
    final notes = [
      _noteModel.noteTajwid,
      _noteModel.noteHousnSawtt,
      if (widget.participant.ageGroup == 'كبار') ...[
        _noteModel.noteOu4oubetSawtt,
        _noteModel.noteWaqfAndIbtidaa,
      ],
      _noteModel.noteIltizamRiwaya,
    ].whereType<double>().toList();

    final total = notes.isEmpty ? 0.0 : notes.reduce((a, b) => a + b);
    setState(() {
      _totalScore = total;
      _noteModel.result = total;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final evaluation = Evaluation(
      id: _existingEvaluation?.id ?? '', // vide = insert
      participantId: widget.participant.id,
      juryId: widget.appUser.id,
      versionId: widget.version.id,
      round: widget.round,
      totalScore: _totalScore,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      submittedAt: DateTime.now(),
      noteModel: _noteModel,
    );

    try {
      if (_existingEvaluation == null) {
        await _evaluationService.submitEvaluation(evaluation, widget.participant.ageGroup);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال التقييم بنجاح')));
      } else {
        await _evaluationService.updateEvaluation(evaluation, widget.participant.ageGroup);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل التقييم بنجاح')));
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء إرسال التقييم: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget _buildSlider(String label, void Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          min: 0,
          max: 20,
          divisions: 20,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildSlider('التجويد', (v) => _noteModel.noteTajwid = v),
                    _buildSlider('حسن الصوت', (v) => _noteModel.noteHousnSawtt = v),
                    if (isAdult)
                      _buildSlider('عذوبة الصوت', (v) => _noteModel.noteOu4oubetSawtt = v),
                    if (isAdult)
                      _buildSlider('الوقف والإبتداء', (v) => _noteModel.noteWaqfAndIbtidaa = v),
                    _buildSlider('الإلتزام بالرواية', (v) => _noteModel.noteIltizamRiwaya = v),
                    const SizedBox(height: 16),
                    Text('النتيجة النهائية: $_totalScore', style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _isSubmitting
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submit,
                            child: Text(_existingEvaluation == null ? 'إرسال التقييم' : 'تحديث التقييم'),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
