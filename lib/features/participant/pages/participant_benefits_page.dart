import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/quranic_benefit_service.dart';
import 'package:quranic_competition/models/quranic_benefit.dart';

class ParticipantBenefitsPage extends StatefulWidget {
  const ParticipantBenefitsPage({super.key});

  @override
  State<ParticipantBenefitsPage> createState() =>
      _ParticipantBenefitsPageState();
}

class _ParticipantBenefitsPageState extends State<ParticipantBenefitsPage> {
  final QuranicBenefitService _benefitService = QuranicBenefitService();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  final ScrollController _scrollController = ScrollController();

  List<QuranicBenefit> _benefits = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  int _totalCount = 0;
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadBenefits(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Annuler le timer précédent s'il existe
    _debounceTimer?.cancel();

    // Mettre à jour le texte affiché immédiatement
    setState(() {
      _searchText = value;
    });

    // Mettre à jour la query pour la recherche
    _searchQuery = value;

    // Créer un nouveau timer pour la recherche avec debounce
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadBenefits(reset: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) {
        _loadMoreBenefits();
      }
    }
  }

  Future<void> _loadBenefits({bool reset = true}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _currentPage = 0;
        _hasMore = true;
      }
    });

    try {
      // Utiliser la méthode spécifique pour les participants (seulement les bénéfices actives)
      final result = await _benefitService.getActiveBenefitsWithPagination(
        searchQuery: _searchQuery,
        page: _currentPage,
        limit: 20,
      );

      setState(() {
        if (reset) {
          _benefits = result['benefits'] as List<QuranicBenefit>;
        } else {
          _benefits.addAll(result['benefits'] as List<QuranicBenefit>);
        }
        _totalCount = result['totalCount'] as int;
        _hasMore = result['hasMore'] as bool;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الفوائد القرآنية: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreBenefits() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    await _loadBenefits(reset: false);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'البحث في الفوائد القرآنية...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _searchText.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged(
                        '',
                      ); // Déclencher la recherche avec une chaîne vide
                    },
                  )
                  : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildBenefitCard(QuranicBenefit benefit) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    benefit.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'فائدة قرآنية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (benefit.imageUrl != null && benefit.imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  benefit.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 50),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              benefit.content,
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'نشر بواسطة: الإدارة',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(benefit.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'لا توجد فوائد قرآنية تطابق البحث'
                  : 'لا توجد فوائد قرآنية متاحة حالياً',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'جرب البحث بكلمات مختلفة'
                  : 'سيتم إضافة فوائد جديدة قريباً',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
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
            const Text('الفوائد القرآنية'),
            if (_totalCount > 0)
              Text(
                '$_totalCount فائدة متاحة',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadBenefits(reset: true),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildSearchBar(),
                  Expanded(
                    child:
                        _benefits.isEmpty && !_isLoading
                            ? _buildEmptyState()
                            : RefreshIndicator(
                              onRefresh: () => _loadBenefits(reset: true),
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount:
                                    _benefits.length + (_hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _benefits.length) {
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
                                            child: ElevatedButton.icon(
                                              onPressed: _loadMoreBenefits,
                                              icon: const Icon(
                                                Icons.expand_more,
                                              ),
                                              label: const Text('تحميل المزيد'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                        )
                                        : const SizedBox.shrink();
                                  }
                                  return _buildBenefitCard(_benefits[index]);
                                },
                              ),
                            ),
                  ),
                ],
              ),
    );
  }
}
