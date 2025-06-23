import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/participant_service.dart';
import '../../../models/competition_version.dart';
import '../../../models/participant.dart'; // à créer selon ton modèle

class VersionDetailPage extends StatefulWidget {
  final CompetitionVersion version;

  const VersionDetailPage({super.key, required this.version});

  @override
  State<VersionDetailPage> createState() => _VersionDetailPageState();
}

class _VersionDetailPageState extends State<VersionDetailPage> {
  final ParticipantService _participantService = ParticipantService();

  List<Participant> _participants = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    setState(() => _isLoading = true);
    _participants = await _participantService.fetchParticipantsByVersion(widget.version.id);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تفاصيل النسخة: ${widget.version.name}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                ListTile(
                  title: Text('السنة: ${widget.version.year}'),
                  subtitle: Text('التسجيل: ${widget.version.isRegistrationOpen ? 'مفتوح' : 'مغلق'}'),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('المشاركون', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: _participants.isEmpty
                      ? const Center(child: Text('لا يوجد مشاركون بعد'))
                      : ListView.builder(
                          itemCount: _participants.length,
                          itemBuilder: (context, index) {
                            final p = _participants[index];
                            return ListTile(
                              title: Text(p.fullName),
                              subtitle: Text('الفئة العمرية: ${p.ageGroup}'),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
