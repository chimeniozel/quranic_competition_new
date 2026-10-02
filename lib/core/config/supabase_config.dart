/// Paramètres de connexion à Supabase.
///
/// Regroupés ici pour qu'un changement de clé se fasse à un seul endroit.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = 'https://slwgmpqpevsodtctpmwz.supabase.co';

  /// Ancienne clé `anon` (JWT signé par le secret JWT du projet).
  ///
  /// Elle reste la valeur par défaut tant que la version publiée sur les
  /// stores l'utilise : régénérer le secret JWT l'invaliderait et bloquerait
  /// toutes les applications déjà installées.
  static const String _legacyAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsd2dtcHFwZXZzb2R0Y3RwbXd6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA0NTYzMjIsImV4cCI6MjA2NjAzMjMyMn0.UpWBLYVgu2-e5I25UTSUewrZiunMTo2xX3Ggb_y4TpI';

  /// Nouvelle clé publiable (`sb_publishable_...`).
  ///
  /// Comme la clé `anon`, elle est conçue pour être embarquée dans
  /// l'application : elle ne donne accès qu'à ce que les politiques RLS
  /// autorisent. Son intérêt est d'être révocable individuellement, sans
  /// toucher au secret JWT — donc sans casser les versions déjà installées.
  ///
  /// Migration :
  ///   1. Créer la clé dans Supabase → Settings → API Keys →
  ///      « Publishable and secret API keys »
  ///   2. La coller ci-dessous, puis publier une mise à jour
  ///   3. Une fois la mise à jour largement installée, désactiver les clés
  ///      JWT historiques (« Disable JWT-based API keys »)
  static const String _publishableKey =
      'sb_publishable_OzSHBxEryIDD7kWvHxP3dw_wqRplC_V';

  /// Clé fournie au lancement, prioritaire sur les constantes ci-dessus.
  ///
  /// Permet d'essayer une clé avant de la livrer :
  ///   flutter run --dart-define=SUPABASE_KEY=sb_publishable_xxx
  static const String _keyFromEnvironment = String.fromEnvironment(
    'SUPABASE_KEY',
  );

  /// Clé utilisée au démarrage : celle passée au lancement, sinon la clé
  /// publiable si elle est renseignée, sinon l'ancienne clé `anon`.
  static String get apiKey {
    if (_keyFromEnvironment.isNotEmpty) return _keyFromEnvironment;
    if (_publishableKey.isNotEmpty) return _publishableKey;
    return _legacyAnonKey;
  }

  /// Vrai tant que l'application utilise encore la clé JWT historique.
  static bool get usesLegacyKey => !apiKey.startsWith('sb_');
}
