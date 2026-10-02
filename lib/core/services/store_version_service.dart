import 'dart:convert';

import 'package:http/http.dart' as http;

/// Lit la version actuellement publiée d'une application sur les stores.
///
/// Sert à remplir automatiquement la version minimale exigée : l'administrateur
/// n'a plus à retenir ni recopier un numéro.
class StoreVersionService {
  static const String androidPackageId = 'com.chemeni.quranic_competition';
  static const String iosBundleId = 'com.chemeni.quranic-competitions';

  static const Duration _timeout = Duration(seconds: 12);

  /// Version publiée sur l'App Store, via l'API publique d'Apple.
  ///
  /// Retourne null si l'application n'est pas encore publiée ou si le réseau
  /// est indisponible.
  Future<String?> fetchIosVersion({String? bundleId}) async {
    final id = bundleId ?? iosBundleId;
    final uri = Uri.parse(
      'https://itunes.apple.com/lookup?bundleId=$id&country=MR',
    );

    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        // L'application peut n'être publiée que dans d'autres pays :
        // nouvelle tentative sans restriction géographique.
        return _fetchIosVersionWorldwide(id);
      }

      final version = (results.first as Map<String, dynamic>)['version'];
      return version is String ? version.trim() : null;
    } catch (e) {
      print('⚠️ Version App Store indisponible: $e');
      return null;
    }
  }

  Future<String?> _fetchIosVersionWorldwide(String bundleId) async {
    try {
      final response = await http
          .get(Uri.parse('https://itunes.apple.com/lookup?bundleId=$bundleId'))
          .timeout(_timeout);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final version = (results.first as Map<String, dynamic>)['version'];
      return version is String ? version.trim() : null;
    } catch (e) {
      return null;
    }
  }

  /// Version publiée sur Google Play.
  ///
  /// Google n'expose pas d'API publique pour cela : la valeur est extraite de
  /// la page du store. C'est fonctionnel mais dépendant de la mise en page de
  /// Google — d'où le retour null, jamais une erreur, si l'extraction échoue.
  /// L'administrateur peut toujours saisir la version à la main.
  Future<String?> fetchAndroidVersion({String? packageId}) async {
    final id = packageId ?? androidPackageId;
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$id&hl=en&gl=US',
    );

    try {
      final response = await http
          .get(uri, headers: const {'User-Agent': 'Mozilla/5.0'})
          .timeout(_timeout);
      if (response.statusCode != 200) return null;

      return _extractPlayStoreVersion(response.body);
    } catch (e) {
      print('⚠️ Version Google Play indisponible: $e');
      return null;
    }
  }

  /// Plusieurs formats coexistent selon les déploiements de Google.
  static String? _extractPlayStoreVersion(String html) {
    final patterns = <RegExp>[
      RegExp(r'\[\[\["(\d+\.\d+(?:\.\d+)*)"\]\]'),
      RegExp(r'Current Version.*?>(\d+\.\d+(?:\.\d+)*)<'),
      RegExp(r'"version"\s*:\s*"(\d+\.\d+(?:\.\d+)*)"'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      final version = match?.group(1);
      if (version != null && version.isNotEmpty) return version;
    }
    return null;
  }

  /// Compare deux numéros de version « 8.3.0 ».
  ///
  /// Retourne un nombre négatif si [a] est antérieure à [b], zéro si elles
  /// sont équivalentes, positif sinon. Les parties manquantes valent 0, si
  /// bien que « 8.3 » et « 8.3.0 » sont équivalentes.
  static int compareVersions(String a, String b) {
    final partsA = _numericParts(a);
    final partsB = _numericParts(b);
    final length = partsA.length > partsB.length ? partsA.length : partsB.length;

    for (var i = 0; i < length; i++) {
      final valueA = i < partsA.length ? partsA[i] : 0;
      final valueB = i < partsB.length ? partsB[i] : 0;
      if (valueA != valueB) return valueA - valueB;
    }
    return 0;
  }

  static List<int> _numericParts(String version) {
    return version
        .trim()
        .split('.')
        .map((part) {
          // Ignore un éventuel suffixe : « 8.3.0-beta » → 0 pour la 3e partie
          final digits = RegExp(r'^\d+').firstMatch(part)?.group(0);
          return int.tryParse(digits ?? '') ?? 0;
        })
        .toList();
  }
}
