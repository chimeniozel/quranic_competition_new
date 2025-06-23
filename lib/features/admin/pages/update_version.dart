import 'package:flutter/material.dart';
import '../../../core/services/competition_version_service.dart';
import '../../../models/competition_version.dart';

class UpdateVersionPage extends StatefulWidget {
  final CompetitionVersion version;

  const UpdateVersionPage({super.key, required this.version});

  @override
  State<UpdateVersionPage> createState() => _UpdateVersionPageState();
}

class _UpdateVersionPageState extends State<UpdateVersionPage> {
  final _service = CompetitionVersionService();

  late TextEditingController _nameController;
  late TextEditingController _yearController;
  late TextEditingController _maxAdultsController;
  late TextEditingController _maxChildrenController;
  bool _isActive = true;
  bool _isRegistrationOpen = true;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.version.name);
    _yearController = TextEditingController(
      text: widget.version.year.toString(),
    );
    _maxAdultsController = TextEditingController(
      text: widget.version.maxAdults.toString(),
    );
    _maxChildrenController = TextEditingController(
      text: widget.version.maxChildren.toString(),
    );
    _isActive = widget.version.isActive;
    _isRegistrationOpen = widget.version.isRegistrationOpen;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    _maxAdultsController.dispose();
    _maxChildrenController.dispose();
    super.dispose();
  }

  Future<void> _submitUpdate() async {
    final name = _nameController.text.trim();
    final year = int.tryParse(_yearController.text.trim());
    final maxAdults = int.tryParse(_maxAdultsController.text.trim());
    final maxChildren = int.tryParse(_maxChildrenController.text.trim());

    if (name.isEmpty ||
        year == null ||
        maxAdults == null ||
        maxChildren == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول بشكل صحيح')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _service.updateVersion(
        id: widget.version.id,
        name: name,
        year: year,
        maxAdults: maxAdults,
        maxChildren: maxChildren,
        isActive: _isActive,
        isRegistrationOpen: _isRegistrationOpen,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث النسخة بنجاح')));

      Navigator.of(context).pop(true); // Retour avec succès
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل النسخة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم النسخة',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'السنة'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _maxAdultsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الحد الأقصى للكبار',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _maxChildrenController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الحد الأقصى للصغار',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: const Text('النسخة نشطة'),
                        value: _isActive,
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                      SwitchListTile(
                        title: const Text('فتح التسجيل'),
                        value: _isRegistrationOpen,
                        onChanged:
                            (val) => setState(() => _isRegistrationOpen = val),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _submitUpdate,
                        child: const Text('تحديث النسخة'),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
