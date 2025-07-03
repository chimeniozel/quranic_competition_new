import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/user_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/evaluation.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';

class VersionJurysPage extends StatefulWidget {
  final CompetitionVersion version;

  const VersionJurysPage({super.key, required this.version});

  @override
  State<VersionJurysPage> createState() => _VersionJurysPageState();
}

class _VersionJurysPageState extends State<VersionJurysPage> {
  final UserService _userService = UserService();
  final EvaluationService _evaluationService = EvaluationService();

  List<AppUser> _jurys = [];
  Map<String, List<Evaluation>> _juryEvaluations = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJurysAndEvaluations();
  }

  Future<void> _loadJurysAndEvaluations() async {
    setState(() => _isLoading = true);
    try {
      final jurys = await _userService.getJurysByVersion(widget.version.id);
      final evaluationsMap = <String, List<Evaluation>>{};

      for (final jury in jurys) {
        final evals = await _evaluationService.getEvaluationsByJuryInVersion(
          juryId: jury.id,
          versionId: widget.version.id,
        );
        evaluationsMap[jury.id] = evals;
      }

      if (!mounted) return;
      setState(() {
        _jurys = jurys;
        _juryEvaluations = evaluationsMap;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ أثناء التحميل: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddJurySheet() async {
    final allJurys = await _userService.getAllJurys();
    final assignedIds = _jurys.map((j) => j.id).toSet();
    final availableJurys =
        allJurys.where((j) => !assignedIds.contains(j.id)).toList();

    if (availableJurys.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("كل المحكمين مسجلين بالفعل")),
      );
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return ListView(
          children:
              availableJurys.map((jury) {
                return ListTile(
                  title: Text(jury.fullName),
                  subtitle: Text(jury.phone ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_add),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _userService.assignJuryToVersion(
                        userId: jury.id,
                        versionId: widget.version.id,
                      );
                      await _loadJurysAndEvaluations();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${jury.fullName} أضيف بنجاح')),
                      );
                    },
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Future<void> _removeJury(AppUser jury) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل تريد حذف ${jury.fullName} وجميع تقييماته؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('تأكيد'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await _userService.removeJuryFromVersion(
        userId: jury.id,
        versionId: widget.version.id,
      );
      await _loadJurysAndEvaluations();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${jury.fullName} تم حذفه بنجاح')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل في الحذف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('لجنة التحكيم - ${widget.version.name}')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddJurySheet,
        child: const Icon(Icons.add_chart_outlined),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _jurys.isEmpty
              ? const Center(child: Text("لا يوجد محكمون لهذه النسخة"))
              : ListView.builder(
                itemCount: _jurys.length,
                itemBuilder: (context, index) {
                  final jury = _jurys[index];
                  final evals = _juryEvaluations[jury.id] ?? [];

                  return ExpansionTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(jury.fullName),
                    subtitle: Text('رقم الهاتف: ${jury.phone}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'حذف المحكم',
                      onPressed: () => _removeJury(jury),
                    ),
                    children:
                        evals.isEmpty
                            ? [const ListTile(title: Text("لا توجد تقييمات"))]
                            : evals
                                .map(
                                  (e) => ListTile(
                                    title: Text("المشارك: ${e.participantId}"),
                                    subtitle: Text("الدرجة: ${e.totalScore}"),
                                  ),
                                )
                                .toList(),
                  );
                },
              ),
    );
  }
}
