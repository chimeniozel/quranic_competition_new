import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/services/competition_version_service.dart';
import '../../../models/competition_version.dart';
import 'package:go_router/go_router.dart';

class VersionManagementPage extends StatefulWidget {
  const VersionManagementPage({super.key});

  @override
  State<VersionManagementPage> createState() => _VersionManagementPageState();
}

class _VersionManagementPageState extends State<VersionManagementPage> {
  final _service = CompetitionVersionService();
  final _nameController = TextEditingController();
  final _maxAdultsController = TextEditingController();
  final _maxChildrenController = TextEditingController();

  bool _isRegistrationOpen = true;
  bool _isAddingLoad = false;

  List<CompetitionVersion> _versions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    _versions = await _service.fetchVersions();
    setState(() => _isLoading = false);
  }

  Future<void> _submitNewVersion() async {
    final name = _nameController.text.trim();
    final maxAdults = int.tryParse(_maxAdultsController.text.trim());
    final maxChildren = int.tryParse(_maxChildrenController.text.trim());

    if (name.isEmpty || maxAdults == null || maxChildren == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول بشكل صحيح')),
      );
      return;
    }

    try {
      setState(() {
        _isAddingLoad = true;
      });
      await _service.createVersion(
        name: name,
        year: DateTime.now().year,
        maxAdults: maxAdults,
        maxChildren: maxChildren,
        isRegistrationOpen: _isRegistrationOpen,
      );
      _nameController.clear();
      _maxAdultsController.clear();
      _maxChildrenController.clear();
      context.pop();
      setState(() {
        _isRegistrationOpen = true;
        _isAddingLoad = false;
      });

      await _loadVersions();
    } catch (e) {
      setState(() {
        _isAddingLoad = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الإضافة: $e')));
    }
  }

  Future<void> showAddDialog() async {
    showDialog(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('إضافة نسخة جديدة'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم النسخة',
                          ),
                        ),
                        TextField(
                          controller: _maxAdultsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الحد الأقصى للكبار',
                          ),
                        ),
                        TextField(
                          controller: _maxChildrenController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الحد الأقصى للصغار',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('فتح التسجيل:'),
                            Switch(
                              value: _isRegistrationOpen,
                              onChanged: (val) {
                                setState(() => _isRegistrationOpen = val);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await _submitNewVersion();
                      },
                      child:
                          _isAddingLoad
                              ? CircularProgressIndicator()
                              : const Text('إضافة'),
                    ),
                  ],
                ),
          ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة النسخ')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showAddDialog();
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _versions.isEmpty
              ? const Center(child: Text('لا توجد نسخ حالياً'))
              : ListView.builder(
                itemCount: _versions.length,
                itemBuilder: (context, index) {
                  final version = _versions[index];
                  return ListTile(
                    onTap: () {
                      context.push('/admin/version_detail', extra: version);
                    },
                    title: Text(version.name),
                    subtitle: Text(
                      'السنة: ${version.year}\n'
                      'الحد الأقصى للكبار: ${version.maxAdults} - للصغار: ${version.maxChildren}\n'
                      'التسجيل: ${version.isRegistrationOpen ? 'مفتوح' : 'مغلق'}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        version.isActive
                            ? const Chip(
                              label: Text('نشطة'),
                              backgroundColor: Colors.green,
                              labelStyle: TextStyle(color: Colors.white),
                            )
                            : const Chip(
                              label: Text('منتهية'),
                              backgroundColor: Colors.red,
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                        IconButton(
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedEdit03,
                            color: Colors.red,
                            size: 25.0,
                          ),
                          onPressed: () async {
                            final result = await context.push<bool>(
                              '/admin/version_update',
                              extra: version,
                            );

                            if (result == true) {
                              // Mise à jour réussie, recharge la liste
                              await _loadVersions();
                              setState(() {});
                            }
                          },
                        ),

                        IconButton(
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedDelete01,
                            color: Colors.red,
                            size: 25.0,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: const Text('تأكيد الحذف'),
                                    content: Text(
                                      'هل تريد حذف النسخة "${version.name}"؟',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, false),
                                        child: const Text('لا'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, true),
                                        child: const Text('نعم'),
                                      ),
                                    ],
                                  ),
                            );

                            if (confirm == true) {
                              try {
                                await _service.deleteVersion(version.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم حذف النسخة'),
                                  ),
                                );
                                _loadVersions();
                              } catch (e) {
                                print('فشل الحذف: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('فشل الحذف: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
