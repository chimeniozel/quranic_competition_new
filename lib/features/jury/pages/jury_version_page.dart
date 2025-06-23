import 'package:flutter/material.dart';
import '../../../core/services/competition_version_service.dart';
import '../../../models/competition_version.dart';
import 'package:go_router/go_router.dart';

class JuryVersionPage extends StatefulWidget {
  const JuryVersionPage({super.key});

  @override
  State<JuryVersionPage> createState() => _JuryVersionPageState();
}

class _JuryVersionPageState extends State<JuryVersionPage> {
  final _service = CompetitionVersionService();

  List<CompetitionVersion> _versions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    _versions = await _service.fetchMyVersions();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ المحكمة من طرفي')),
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
                      context.push('/jury/version_detail_page', extra: version);
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
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
