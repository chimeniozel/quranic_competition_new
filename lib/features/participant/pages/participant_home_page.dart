import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/competition_version_service.dart';
import '../../../models/competition_version.dart';

class ParticipantHomePage extends StatefulWidget {
  const ParticipantHomePage({super.key});

  @override
  State<ParticipantHomePage> createState() => _ParticipantHomePageState();
}

class _ParticipantHomePageState extends State<ParticipantHomePage> {
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
    _versions = await _service.fetchVersions();
    setState(() => _isLoading = false);
  }

  void _goToRegister(String versionId) {
    // Naviguer vers la page d'inscription participant en passant versionId
    context.go('/participant/register', extra: versionId);
  }

  void _goToVersionDetail(CompetitionVersion version) {
    // Naviguer vers les détails de la version (supposons route configurée)
    context.go('/admin/version_detail', extra: version);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الصفحة الرئيسة'),
        leading: IconButton(
          icon: const Icon(Icons.login),
          tooltip: 'Se connecter',
          onPressed: () {
            // Naviguer vers la page login
            // Exemple avec GoRouter :
            context.push('/login');
          },
        ),
      ),

      body: Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () {
                    context.push(
                      '/participant/register',
                      extra: {
                        'versionId': '339b17e2-2c17-49c2-9f1a-55d0f31c445c',
                        'ageGroup': 'صغار',
                      },
                    );
                  },
                  child: Text("سجل الصغار"),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.push(
                      '/participant/register',
                      extra: {
                        'versionId': '339b17e2-2c17-49c2-9f1a-55d0f31c445c',
                        'ageGroup': 'كبار',
                      },
                    );
                  },
                  child: Text("سجل الكبار"),
                ),
              ],
            ),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () {
                context.push('/participant_result_page');
              },
              child: Text("نتائج المسابقة"),
            ),
            const SizedBox(height: 20.0),
            ElevatedButton.icon(
              onPressed: () {
                print('🔍 Tentative de navigation vers /participant/benefits');
                context.push('/participant/benefits');
              },
              icon: const Icon(Icons.menu_book),
              label: const Text("الفوائد القرآنية"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20.0),
            ElevatedButton.icon(
              onPressed: () {
                context.push('/participant/tajweed');
              },
              icon: const Icon(Icons.auto_stories),
              label: const Text("أحكام التجويد"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                context.push('/participant/quiz');
              },
              icon: const Icon(Icons.quiz),
              label: const Text("مسابقات التجويد"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                context.push('/participant/archives');
              },
              icon: const Icon(Icons.archive),
              label: const Text("أرشيف المسابقات"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
