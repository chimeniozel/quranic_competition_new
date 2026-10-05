import 'package:shared_preferences/shared_preferences.dart';

/// Mémorise, **sur l'appareil**, les فوائد قرآنية déjà ouvertes.
///
/// Une فائدة ouverte n'est plus signalée comme « جديد » pour cet utilisateur.
/// Comme pour les notifications, l'état est local : les participants n'ont
/// pas de compte, et une même فائدة est partagée par tous les appareils.
class BenefitReadStore {
  static final BenefitReadStore _instance = BenefitReadStore._();
  factory BenefitReadStore() => _instance;
  BenefitReadStore._();

  static const String _storageKey = 'read_benefit_ids';

  /// Une فائدة n'est « جديد » que quelques jours : inutile de garder un
  /// historique illimité d'identifiants.
  static const int _maxStoredIds = 300;

  List<String>? _cache;

  Future<List<String>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;

    try {
      final prefs = await SharedPreferences.getInstance();
      _cache = prefs.getStringList(_storageKey) ?? <String>[];
    } catch (e) {
      // Stockage indisponible : tout est considéré comme non lu
      _cache = <String>[];
    }
    return _cache!;
  }

  /// Identifiants des فوائد déjà ouvertes sur cet appareil.
  Future<Set<String>> readIds() async => (await _load()).toSet();

  Future<void> markRead(String id) async {
    if (id.isEmpty) return;
    final stored = await _load();
    if (stored.contains(id)) return;

    stored.add(id);
    if (stored.length > _maxStoredIds) {
      stored.removeRange(0, stored.length - _maxStoredIds);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, stored);
    } catch (e) {
      // L'état reste au moins correct pour la session en cours.
    }
  }
}
