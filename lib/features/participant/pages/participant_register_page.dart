import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/participant_service.dart';
import 'package:quranic_competition/models/participant.dart';

class ParticipantRegisterPage extends StatefulWidget {
  final String versionId;
  final String ageGroup;
  const ParticipantRegisterPage({
    super.key,
    required this.versionId,
    required this.ageGroup,
  });

  @override
  State<ParticipantRegisterPage> createState() =>
      _ParticipantRegisterPageState();
}

class _ParticipantRegisterPageState extends State<ParticipantRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = ParticipantService();

  // Controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _residenceController = TextEditingController();

  String? _quranMemorized;
  String? _readingMethods;
  String? _gender;
  String? _residence;

  bool _hasIjaza = false;
  bool _wonPreviousRanks = false;
  bool _participatedBefore = false;
  DateTime? _selectedBirthDate;
  bool _isLoading = false;

  Future<void> _pickBirthDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (date != null) {
      setState(() {
        _selectedBirthDate = date;
        _birthDateController.text = date.toLocal().toString().split(' ')[0];
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار تاريخ الميلاد')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final participant = Participant(
      id: '',
      fullName: _fullNameController.text.trim(),
      gender: _gender ?? '',
      birthDate: _selectedBirthDate!,
      phone: _phoneController.text.trim(),
      quranMemorized: _quranMemorized ?? "",
      readingMethods: _readingMethods ?? "",
      residence: _residenceController.text.trim(),
      hasIjaza: _hasIjaza,
      wonPreviousRanks: _wonPreviousRanks,
      participatedBefore: _participatedBefore,
      ageGroup: widget.ageGroup,
      createdAt: DateTime.now(),
      isAccepted: true,
    );

    try {
      await _service.registerParticipant(
        participant: participant,
        versionId: widget.versionId,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم التسجيل بنجاح')));
      Navigator.of(context).pop();
    } catch (e) {
      print('فشل التسجيل: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التسجيل: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ageGroup == "كبار" ? 'تسجيل الكبار' : 'تسجيل الصغار',
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الثلاثي',
                        ),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'هذا الحقل مطلوب'
                                    : null,
                      ),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        items: const [
                          DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                          DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                        ],
                        onChanged: (value) => setState(() => _gender = value),
                        decoration: const InputDecoration(labelText: 'الجنس'),
                        validator: (v) => v == null ? 'اختر الجنس' : null,
                      ),
                      TextFormField(
                        controller: _birthDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'تاريخ الميلاد',
                        ),
                        onTap: _pickBirthDate,
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'هذا الحقل مطلوب'
                                    : null,
                      ),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                        ),
                        keyboardType: TextInputType.phone,
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'هذا الحقل مطلوب'
                                    : null,
                      ),
                      DropdownButtonFormField<String>(
                        value: _quranMemorized,
                        items: const [
                          DropdownMenuItem(
                            value: 'القرآن كاملاً',
                            child: Text('القرآن كاملاً'),
                          ),
                          DropdownMenuItem(
                            value: 'نصف القرآن',
                            child: Text('نصف القرآن'),
                          ),
                          DropdownMenuItem(
                            value: 'أقل من نصف',
                            child: Text('أقل من نصف'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _quranMemorized = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'كم تحفظ من القرآن',
                        ),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'اختر مستوى الحفظ'
                                    : null,
                      ),

                      DropdownButtonFormField<String>(
                        value: _readingMethods,
                        items: const [
                          DropdownMenuItem(
                            value: 'رواية واحدة',
                            child: Text('رواية واحدة'),
                          ),
                          DropdownMenuItem(
                            value: 'أكثر من رواية',
                            child: Text('أكثر من رواية'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _readingMethods = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'كم رواية تقرأ بها',
                        ),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'اختر عدد الروايات'
                                    : null,
                      ),

                      DropdownButtonFormField<String>(
                        value: _residence,
                        items: const [
                          DropdownMenuItem(
                            value: 'داخل موريتانيا',
                            child: Text('داخل موريتانيا'),
                          ),
                          DropdownMenuItem(
                            value: 'خارج موريتانيا',
                            child: Text('خارج موريتانيا'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _residence = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'مكان الإقامة الحالية',
                        ),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'اختر مكان الإقامة'
                                    : null,
                      ),

                      SwitchListTile(
                        title: const Text('هل حصلت على إجازة؟'),
                        value: _hasIjaza,
                        onChanged: (v) => setState(() => _hasIjaza = v),
                      ),
                      SwitchListTile(
                        title: const Text(
                          'هل حصلت على المراتب 1 إلى 2 في مسابقة أهل القرآن أو غيرها؟',
                        ),
                        value: _wonPreviousRanks,
                        onChanged: (v) => setState(() => _wonPreviousRanks = v),
                      ),
                      SwitchListTile(
                        title: const Text('هل شاركت في نسخة ماضية؟'),
                        value: _participatedBefore,
                        onChanged:
                            (v) => setState(() => _participatedBefore = v),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _submit,
                        child: const Text('تسجيل'),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
