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
  final ScrollController _scrollController = ScrollController();

  List<Participant> _allParticipants = [];
  List<Participant> _filteredParticipants = [];
  String _selectedGroup = 'كبار';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  int _totalCount = 0;
  String _searchQuery = '';
  AppUser? appUser;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadParticipants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants({bool reset = true}) async {
    if (reset) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      AuthService authService = AuthService();
      AppUser? user = await authService.getUserProfile();

      // Charger tous les participants (seulement au premier chargement)
      if (reset) {
        final participants = await _participantService
            .fetchParticipantsByVersion(widget.version.id);
        setState(() {
          appUser = user;
          _allParticipants = participants;
        });
      }

      // Appliquer les filtres et la pagination
      _applyFilter(reset: reset);
    } catch (e) {
      print("Erreur lors du chargement des participants: $e");
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _applyFilter({bool reset = true}) {
    List<Participant> filtered =
        _allParticipants.where((p) => p.ageGroup == _selectedGroup).toList();

    // Appliquer la recherche
    if (_searchQuery.isNotEmpty) {
      int? searchTerm = int.tryParse(_searchQuery.trim());
      if (searchTerm != null) {
        filtered =
            filtered.where((p) => p.registrationNumber == searchTerm).toList();
      }
    }

    // Appliquer la pagination côté client
    final totalCount = filtered.length;
    final startIndex = _currentPage * 20;
    final endIndex = (startIndex + 20).clamp(0, totalCount);

    final paginatedParticipants = filtered.sublist(startIndex, endIndex);

    setState(() {
      if (reset) {
        _filteredParticipants = paginatedParticipants;
        _currentPage = 0;
      } else {
        _filteredParticipants.addAll(paginatedParticipants);
      }
      _totalCount = totalCount;
      _hasMore = endIndex < totalCount;
    });
  }

  void _onSearchChanged() {
    _searchQuery = _searchController.text;
    _loadParticipants(reset: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) {
        _loadMoreParticipants();
      }
    }
  }

  Future<void> _loadMoreParticipants() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _currentPage++);
    await _loadParticipants(reset: false);
  }

  void _selectGroup(String group) {
    if (group != _selectedGroup) {
      setState(() {
        _selectedGroup = group;
        _currentPage = 0;
        _hasMore = true;
      });
      _loadParticipants(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.version.name),
            if (_totalCount > 0)
              Text(
                'إجمالي: $_totalCount مشارك',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text(
              'لجنة التحكيم',
              style: TextStyle(color: Colors.white),
            ),
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
                        _filteredParticipants.isEmpty && !_isLoading
                            ? const Center(
                              child: Text('لا يوجد مشاركون في هذه الفئة'),
                            )
                            : RefreshIndicator(
                              onRefresh: () => _loadParticipants(reset: true),
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount:
                                    _filteredParticipants.length +
                                    (_hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _filteredParticipants.length) {
                                    // Indicateur de chargement en bas
                                    return _isLoadingMore
                                        ? const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                        : _hasMore
                                        ? Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Center(
                                            child: ElevatedButton(
                                              onPressed: _loadMoreParticipants,
                                              child: const Text('تحميل المزيد'),
                                            ),
                                          ),
                                        )
                                        : const SizedBox.shrink();
                                  }
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
                  ),
                ],
              ),
    );
  }
}
