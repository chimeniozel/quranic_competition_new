/// Outils communs aux champs de recherche de l'application.
///
/// Règle : une saisie composée uniquement de chiffres (ex: "4") est une
/// recherche par numéro et doit trouver exactement ce numéro, sans afficher
/// les autres numéros qui le contiennent (14, 40, 404...).
class SearchUtils {
  SearchUtils._();

  static const _easternDigits = '٠١٢٣٤٥٦٧٨٩';
  static const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

  /// Convertit les chiffres arabes orientaux (٠-٩) et persans (۰-۹) en
  /// chiffres latins.
  static String normalizeDigits(String input) {
    final buffer = StringBuffer();
    for (final char in input.split('')) {
      var index = _easternDigits.indexOf(char);
      if (index < 0) index = _persianDigits.indexOf(char);
      buffer.write(index >= 0 ? index.toString() : char);
    }
    return buffer.toString();
  }

  /// Retourne les chiffres saisis si la recherche est purement numérique
  /// (espaces et tirets ignorés, préfixe "+" accepté), sinon null.
  static String? numericQuery(String query) {
    final compact = normalizeDigits(
      query.trim(),
    ).replaceAll(RegExp(r'[\s\-]'), '').replaceFirst(RegExp(r'^\+'), '');
    if (compact.isEmpty || !RegExp(r'^\d+$').hasMatch(compact)) return null;
    return compact;
  }

  /// Vrai si [value] (numéro, téléphone, année...) correspond exactement aux
  /// chiffres [digits]. Les zéros en tête et la mise en forme sont ignorés.
  static bool numberMatches(Object? value, String digits) {
    if (value == null) return false;
    final valueDigits = normalizeDigits(
      value.toString(),
    ).replaceAll(RegExp(r'\D'), '');
    if (valueDigits.isEmpty) return false;
    return _stripLeadingZeros(valueDigits) == _stripLeadingZeros(digits);
  }

  static String _stripLeadingZeros(String digits) {
    final stripped = digits.replaceFirst(RegExp(r'^0+'), '');
    return stripped.isEmpty ? '0' : stripped;
  }
}
