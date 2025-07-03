import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/services/participant_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/filter_button.dart';
import '../../../models/competition_version.dart';
import '../../../models/participant.dart';

class VersionDetailPage extends StatefulWidget {
  final CompetitionVersion version;

  const VersionDetailPage({super.key, required this.version});

  @override
  State<VersionDetailPage> createState() => _VersionDetailPageState();
}

class _VersionDetailPageState extends State<VersionDetailPage> {
  final ParticipantService _participantService = ParticipantService();
  final TextEditingController _searchController = TextEditingController();

  List<Participant> _allParticipants = [];
  List<Participant> _filteredParticipants = [];
  String _selectedGroup = 'كبار';
  bool _isLoading = false;
  AppUser? appUser;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _loadParticipants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    setState(() => _isLoading = true);
    AuthService authService = AuthService();
    AppUser? user = await authService.getUserProfile();
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
    List<Participant> filtered =
        _allParticipants.where((p) => p.ageGroup == _selectedGroup).toList();

    int? searchTerm = int.tryParse(_searchController.text.trim());
    if (searchTerm != null) {
      filtered =
          filtered.where((p) => p.registrationNumber == (searchTerm)).toList();
    }

    setState(() {
      _filteredParticipants = filtered;
    });
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
      appBar: AppBar(
        title: Text('تفاصيل النسخة: ${widget.version.name}'),
        actions: [
          TextButton(
            child: const Text('لجنة التحكيم'),
            onPressed: () {
              context.pushNamed('jury-version-jurys', extra: widget.version);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Container(
          padding: const EdgeInsets.all(8),
          child: const Text("النتائج"),
        ),
        onPressed: () async {
          context.push('/admin/version_results', extra: widget.version);
        },
      ),
      body:
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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: TextField(
                      controller: _searchController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن اسم المشارك...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}
