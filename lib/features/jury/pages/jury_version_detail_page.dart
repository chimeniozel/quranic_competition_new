import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/services/participant_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/jury_evaluation_args.dart';
import '../../../models/competition_version.dart';
import '../../../models/participant.dart';

class JuryVersionDetailPage extends StatefulWidget {
  final CompetitionVersion version;

  const JuryVersionDetailPage({super.key, required this.version});

  @override
  State<JuryVersionDetailPage> createState() => _JuryVersionDetailPageState();
}

class _JuryVersionDetailPageState extends State<JuryVersionDetailPage> {
  final ParticipantService _participantService = ParticipantService();

  List<Participant> _allParticipants = [];
  List<Participant> _filteredParticipants = [];
  String _selectedGroup = 'all';
  bool _isLoading = false;
  AppUser? appUser;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {

    AuthService authService = AuthService();
    AppUser? user = await authService.getUserProfile();
    setState(() => _isLoading = true);
    final participants = await _participantService.fetchParticipantsByVersion(
      widget.version.id,
    );
    setState(() {
      appUser = user;
      _allParticipants = participants;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    if (_selectedGroup == 'all') {
      _filteredParticipants = _allParticipants;
    } else {
      _filteredParticipants =
          _allParticipants.where((p) => p.ageGroup == _selectedGroup).toList();
    }
  }

  void _selectGroup(String group) {
    setState(() {
      _selectedGroup = group;
      _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تفاصيل النسخة: ${widget.version.name}')),
      body: Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    ListTile(
                      title: Text('السنة: ${widget.version.year}'),
                      subtitle: Text(
                        'التسجيل: ${widget.version.isRegistrationOpen ? 'مفتوح' : 'مغلق'}',
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FilterButton(
                            label: 'الكل',
                            selected: _selectedGroup == 'all',
                            onTap: () => _selectGroup('all'),
                          ),
                          FilterButton(
                            label: 'كبار',
                            selected: _selectedGroup == 'كبار',
                            onTap: () => _selectGroup('كبار'),
                          ),
                          FilterButton(
                            label: 'صغار',
                            selected: _selectedGroup == 'صغار',
                            onTap: () => _selectGroup('صغار'),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'المشاركون',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          _filteredParticipants.isEmpty
                              ? const Center(
                                child: Text('لا يوجد مشاركون في هذه الفئة'),
                              )
                              : ListView.builder(
                                itemCount: _filteredParticipants.length,
                                itemBuilder: (context, index) {
                                  final participant =
                                      _filteredParticipants[index];
                                  return ListTile(
                                    title: Text(participant.fullName),
                                    subtitle: Text(
                                      'الفئة: ${participant.ageGroup} - رقم التسجيل: ${participant.registrationNumber}',
                                    ),
                                    trailing: TextButton(
                                      onPressed: () {
                                        context.push(
                                          '/jury/participant',
                                          extra: JuryEvaluationArgs(
                                            participant: participant,
                                            appUser: appUser!,
                                            version: widget.version,
                                            round: 1,
                                          ),
                                        );
                                      },
                                      child: Text("تصيح المسابقة"),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class FilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FilterButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.green : Colors.grey,
      ),
      child: Text(label, style: TextStyle(color: Colors.black)),
    );
  }
}
