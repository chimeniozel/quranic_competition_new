import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/models/round_result.dart';
import 'package:quranic_competition/models/round.dart';
import '../../../core/services/round_results_service.dart';
import '../../../core/services/competition_version_service.dart';
import '../../../core/services/round_service.dart';
import '../../../models/competition_version.dart';

class ParticipantResultPage extends StatefulWidget {
  const ParticipantResultPage({super.key});

  @override
  State<ParticipantResultPage> createState() => _ParticipantResultPageState();
}

class _ParticipantResultPageState extends State<ParticipantResultPage> {
  final RoundResultsService _resultsService = RoundResultsService();
  final CompetitionVersionService _versionService = CompetitionVersionService();
  final RoundService _roundService = RoundService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  int _totalCount = 0;
  String _selectedAgeGroup = 'كبار';
  CompetitionVersion? _selectedVersion;
  Round? _selectedRound;
  List<CompetitionVersion> _versions = [];
  List<Round> _rounds = [];
  List<RoundResult> _results = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadVersions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    try {
      _versions = await _versionService.fetchVersions();
      if (_versions.isNotEmpty) {
        _selectedVersion = _versions.first;
        await _loadRounds();
      }
    } catch (e) {
      print('Erreur lors du chargement des versions: $e');
      _showErrorSnackBar('خطأ أثناء تحميل النسخ');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRounds() async {
    if (_selectedVersion == null) return;

    setState(() => _isLoading = true);
    try {
      _rounds = await _roundService.getRoundsByVersion(_selectedVersion!.id);
      if (_rounds.isNotEmpty) {
        _selectedRound = _rounds.first;
        await _loadResults();
      }
    } catch (e) {
      print('Erreur lors du chargement des tours: $e');
      _showErrorSnackBar('خطأ أثناء تحميل الجولات');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadResults({bool reset = true}) async {
    if (_selectedVersion == null || _selectedRound == null) return;

    if (reset) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final result = await _resultsService.getResultsWithPagination(
        roundId: _selectedRound!.id,
        ageGroup: _selectedAgeGroup,
        page: _currentPage,
        limit: 20,
      );

      setState(() {
        if (reset) {
          _results = result['results'] as List<RoundResult>;
          _currentPage = 0;
        } else {
          _results.addAll(result['results'] as List<RoundResult>);
        }
        _totalCount = result['totalCount'] as int;
        _hasMore = result['hasMore'] as bool;
        _currentPage = result['currentPage'] as int;
      });
    } catch (e) {
      print('Erreur lors du chargement des résultats: $e');
      _showErrorSnackBar('خطأ أثناء تحميل النتائج');
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) {
        _loadMoreResults();
      }
    }
  }

  Future<void> _loadMoreResults() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _currentPage++);
    await _loadResults(reset: false);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildVersionSelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر النسخة:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<CompetitionVersion>(
              value: _selectedVersion,
              isExpanded: true,
              items:
                  _versions.map((version) {
                    return DropdownMenuItem(
                      value: version,
                      child: Text(version.name),
                    );
                  }).toList(),
              onChanged: (version) {
                if (version != null && version.id != _selectedVersion?.id) {
                  setState(() {
                    _selectedVersion = version;
                    _currentPage = 0;
                    _hasMore = true;
                  });
                  _loadRounds();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundSelector() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر الجولة:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<Round>(
              value: _selectedRound,
              isExpanded: true,
              items:
                  _rounds.map((round) {
                    return DropdownMenuItem(
                      value: round,
                      child: Text('الجولة ${round.number} - ${round.name}'),
                    );
                  }).toList(),
              onChanged: (round) {
                if (round != null && round.id != _selectedRound?.id) {
                  setState(() {
                    _selectedRound = round;
                    _currentPage = 0;
                    _hasMore = true;
                  });
                  _loadResults(reset: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeGroupSelector() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر الفئة:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('كبار'),
                    value: 'كبار',
                    groupValue: _selectedAgeGroup,
                    onChanged: (value) {
                      if (value != null && value != _selectedAgeGroup) {
                        setState(() {
                          _selectedAgeGroup = value;
                          _currentPage = 0;
                          _hasMore = true;
                        });
                        _loadResults(reset: true);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('صغار'),
                    value: 'صغار',
                    groupValue: _selectedAgeGroup,
                    onChanged: (value) {
                      if (value != null && value != _selectedAgeGroup) {
                        setState(() {
                          _selectedAgeGroup = value;
                          _currentPage = 0;
                          _hasMore = true;
                        });
                        _loadResults(reset: true);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedRound != null
                  ? 'لا توجد نتائج متاحة للجولة ${_selectedRound!.name}'
                  : 'لا توجد نتائج متاحة',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // En-tête avec les informations de sélection
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'نتائج ${_selectedVersion?.name ?? ""}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'الجولة: ${_selectedRound?.name ?? ""} - الفئة: $_selectedAgeGroup',
                style: const TextStyle(fontSize: 14, color: Colors.blue),
              ),
              const SizedBox(height: 4),
              Text(
                'عدد المشاركين: ${_results.length}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        // Liste des résultats
        ...(_results.map((result) {
          final index = _results.indexOf(result);
          return _buildResultCard(result, index + 1);
        }).toList()),

        // Indicateur de chargement en bas
        if (_hasMore)
          _isLoadingMore
              ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ElevatedButton(
                    onPressed: _loadMoreResults,
                    child: const Text('تحميل المزيد'),
                  ),
                ),
              ),

        const SizedBox(height: 20), // Espace en bas pour le scroll
      ],
    );
  }

  Widget _buildResultCard(RoundResult result, int rank) {
    Color medalColor;
    IconData medalIcon;

    if (rank == 1) {
      medalColor = Colors.amber;
      medalIcon = Icons.emoji_events;
    } else if (rank == 2) {
      medalColor = Colors.grey;
      medalIcon = Icons.emoji_events;
    } else if (rank == 3) {
      medalColor = Colors.brown;
      medalIcon = Icons.emoji_events;
    } else {
      medalColor = Colors.blue;
      medalIcon = Icons.person;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 2,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: medalColor.withOpacity(0.1),
            child: Icon(medalIcon, color: medalColor),
          ),
          title: Text(
            result.participant.fullName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الجولة: ${result.round.name}'),
              Text('النتيجة: ${result.score.toStringAsFixed(2)}'),
              Row(
                children: [
                  Icon(
                    result.passed ? Icons.check_circle : Icons.cancel,
                    color: result.passed ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    result.passed ? 'نجح' : 'لم ينجح',
                    style: TextStyle(
                      color: result.passed ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: medalColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'الترتيب: $rank',
              style: TextStyle(color: medalColor, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('نتائج المسابقة'),
            if (_totalCount > 0)
              Text(
                'إجمالي: $_totalCount نتيجة',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: () => _loadResults(reset: true),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildVersionSelector(),
                      _buildRoundSelector(),
                      _buildAgeGroupSelector(),
                      _buildResultsList(),
                    ],
                  ),
                ),
              ),
    );
  }
}
