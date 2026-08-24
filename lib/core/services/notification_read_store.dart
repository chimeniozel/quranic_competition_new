import 'package:shared_preferences/shared_preferences.dart';

/// Mémorise, **sur l'appareil**, les notifications déjà lues.
///
/// Une notification publique (`user_id = NULL`) est une seule ligne partagée
/// par tous les appareils : écrire `is_read` en base la ferait disparaître
/// pour tout le monde. Et les participants n'ayant pas de compte, il n'y a de
/// toute façon rien à enregistrer côté serveur pour eux.
class NotificationReadStore {
  static final NotificationReadStore _instance = NotificationReadStore._();
  factory NotificationReadStore() => _instance;
  NotificationReadStore._();

  static const String _storageKey = 'read_notification_ids';

  /// Date à partir de laquelle les notifications sont affichées : posée à la
  /// première ouverture après installation. Une réinstallation repart donc à
  /// zéro, sans ressortir les anciennes annonces.
  static const String _sinceKey = 'notifications_since';

  /// Les notifications affichées se limitent à 30 jours : inutile de garder
  /// un historique illimité d'identifiants.
  static const int _maxStoredIds = 500;

  List<String>? _cache;

  Future<List<String>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;

    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_storageKey) ?? <String>[];
      _cache = ids;
      return ids;
    } catch (e) {
      // Stockage indisponible : on considère tout comme non lu plutôt que de
      // faire échouer l'écran des notifications.
      _cache = <String>[];
      return _cache!;
    }
  }

  /// Date de première ouverture de l'application sur cet appareil.
  ///
  /// Les notifications antérieures ne concernent pas cet utilisateur : après
  /// une désinstallation/réinstallation, il repart d'une liste vide.
  Future<DateTime> notificationsSince() async {
    final fallback = DateTime.now().toUtc().subtract(const Duration(days: 30));

    try {
      final prefs = await SharedPreferences.getInstance();

      final stored = prefs.getString(_sinceKey);
      if (stored != null) {
        final parsed = DateTime.tryParse(stored);
        if (parsed != null) return parsed;
      }

      // Première ouverture : on pose le repère maintenant.
      final now = DateTime.now().toUtc();
      await prefs.setString(_sinceKey, now.toIso8601String());
      return now;
    } catch (e) {
      // Stockage indisponible : on retombe sur la fenêtre habituelle.
      return fallback;
    }
  }

  /// Identifiants des notifications lues sur cet appareil.
  Future<Set<String>> readIds() async => (await _load()).toSet();

  Future<bool> isRead(String id) async => (await _load()).contains(id);

  Future<void> markRead(String id) => markAllRead([id]);

  Future<void> markAllRead(Iterable<String> ids) async {
    final stored = await _load();

    var changed = false;
    for (final id in ids) {
      if (id.isEmpty || stored.contains(id)) continue;
      stored.add(id);
      changed = true;
    }
    if (!changed) return;

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
