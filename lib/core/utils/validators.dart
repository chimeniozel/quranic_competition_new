/// Validations communes des formulaires.
class Validators {
  Validators._();

  // Extension de domaine de 2 lettres ou plus (.mr, .com, .online...) :
  // l'ancienne règle refusait les extensions de plus de 4 lettres.
  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  /// Les espaces en début/fin (souvent ajoutés par l'autocomplétion du
  /// clavier) sont ignorés : l'email est de toute façon envoyé « trimé ».
  static bool isValidEmail(String email) => _emailRegex.hasMatch(email.trim());
}
