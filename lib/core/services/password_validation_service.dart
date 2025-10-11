import 'package:flutter/material.dart';

/// Résultat de validation détaillé
class PasswordValidationResult {
  final bool isValid;
  final int strength;
  final String strengthText;
  final Color strengthColor;
  final List<String> errors;
  final List<String> warnings;
  final List<String> suggestions;

  PasswordValidationResult({
    required this.isValid,
    required this.strength,
    required this.strengthText,
    required this.strengthColor,
    required this.errors,
    required this.warnings,
    required this.suggestions,
  });
}

/// Service centralisé pour la validation des mots de passe
/// Fournit des règles de sécurité avancées et une validation robuste
class PasswordValidationService {
  static final PasswordValidationService _instance =
      PasswordValidationService._internal();
  factory PasswordValidationService() => _instance;
  PasswordValidationService._internal();

  /// Configuration des règles de validation
  static const Map<String, dynamic> _passwordRules = {
    'minLength': 8,
    'maxLength': 128,
    'requireUppercase': true,
    'requireLowercase': true,
    'requireNumbers': true,
    'requireSpecialChars': false, // Optionnel pour plus de flexibilité
    'maxConsecutiveChars': 3,
    'maxRepeatedChars': 2,
    'commonPasswords': [
      'password',
      '123456',
      '123456789',
      '12345678',
      '12345',
      '1234567',
      '1234567890',
      'qwerty',
      'abc123',
      'password123',
      'admin',
      'letmein',
      'welcome',
      'monkey',
      '1234567890',
      'password1',
      'qwerty123',
      'dragon',
      'master',
      'hello',
      'freedom',
      'whatever',
      'qazwsx',
      'trustno1',
      '654321',
      'jordan23',
      'harley',
      'password1',
      'jordan',
      'superman',
      'michael',
      'football',
      'shadow',
      'master',
      'jennifer',
      'hockey',
      'killer',
      'george',
      'andrew',
      'charlie',
      'superman',
      'asshole',
      'fuckyou',
      'dallas',
      'jessica',
      'panties',
      'pepper',
      '1234',
      'zxcvbn',
      '555555',
      'fuck',
      'test',
      'robert',
      'batman',
      'thomas',
    ],
  };

  /// Valide un mot de passe et retourne un résultat détaillé
  PasswordValidationResult validatePassword(String password) {
    List<String> errors = [];
    List<String> warnings = [];
    List<String> suggestions = [];
    int strength = 0;

    // Vérifications de base
    if (password.isEmpty) {
      errors.add('كلمة المرور مطلوبة');
      return PasswordValidationResult(
        isValid: false,
        strength: 0,
        strengthText: 'غير موجود',
        strengthColor: Colors.red,
        errors: errors,
        warnings: warnings,
        suggestions: suggestions,
      );
    }

    // Longueur minimale
    if (password.length < _passwordRules['minLength']) {
      errors.add(
        'كلمة المرور يجب أن تكون على الأقل ${_passwordRules['minLength']} أحرف',
      );
    } else {
      strength++;
    }

    // Longueur maximale
    if (password.length > _passwordRules['maxLength']) {
      errors.add(
        'كلمة المرور طويلة جداً (الحد الأقصى ${_passwordRules['maxLength']} حرف)',
      );
    }

    // Majuscules
    if (_passwordRules['requireUppercase'] &&
        !password.contains(RegExp(r'[A-Z]'))) {
      errors.add('يجب أن تحتوي على حرف كبير واحد على الأقل');
    } else if (password.contains(RegExp(r'[A-Z]'))) {
      strength++;
    }

    // Minuscules
    if (_passwordRules['requireLowercase'] &&
        !password.contains(RegExp(r'[a-z]'))) {
      errors.add('يجب أن تحتوي على حرف صغير واحد على الأقل');
    } else if (password.contains(RegExp(r'[a-z]'))) {
      strength++;
    }

    // Chiffres
    if (_passwordRules['requireNumbers'] &&
        !password.contains(RegExp(r'[0-9]'))) {
      errors.add('يجب أن تحتوي على رقم واحد على الأقل');
    } else if (password.contains(RegExp(r'[0-9]'))) {
      strength++;
    }

    // Caractères spéciaux (optionnel)
    if (_passwordRules['requireSpecialChars'] &&
        !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('يجب أن تحتوي على حرف خاص واحد على الأقل (!@#\$%^&*)');
    } else if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      strength++;
    }

    // Vérifications de sécurité avancées
    _checkCommonPasswords(password, errors);
    _checkConsecutiveCharacters(password, warnings);
    _checkRepeatedCharacters(password, warnings);
    _checkKeyboardPatterns(password, warnings);
    _checkPersonalInfo(password, warnings);

    // Calcul de la force finale
    strength = (strength * 2).clamp(0, 10).round(); // Normaliser sur 10

    // Suggestions d'amélioration
    if (strength < 6) {
      suggestions.addAll(_generateSuggestions(password));
    }

    // Déterminer le texte et la couleur de force
    String strengthText;
    Color strengthColor;

    if (strength <= 2) {
      strengthText = 'ضعيف جداً';
      strengthColor = Colors.red;
    } else if (strength <= 4) {
      strengthText = 'ضعيف';
      strengthColor = Colors.orange;
    } else if (strength <= 6) {
      strengthText = 'متوسط';
      strengthColor = Colors.yellow.shade700;
    } else if (strength <= 8) {
      strengthText = 'قوي';
      strengthColor = Colors.lightGreen;
    } else {
      strengthText = 'قوي جداً';
      strengthColor = Colors.green;
    }

    return PasswordValidationResult(
      isValid: errors.isEmpty,
      strength: strength,
      strengthText: strengthText,
      strengthColor: strengthColor,
      errors: errors,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// Vérifie si le mot de passe est dans la liste des mots de passe courants
  void _checkCommonPasswords(String password, List<String> errors) {
    final commonPasswords = _passwordRules['commonPasswords'] as List<String>;
    if (commonPasswords.contains(password.toLowerCase())) {
      errors.add('كلمة المرور شائعة جداً وغير آمنة');
    }
  }

  /// Vérifie les caractères consécutifs (123, abc, etc.)
  void _checkConsecutiveCharacters(String password, List<String> warnings) {
    final maxConsecutive = _passwordRules['maxConsecutiveChars'] as int;

    // Vérifier les chiffres consécutifs
    for (int i = 0; i <= password.length - maxConsecutive; i++) {
      String sequence = password.substring(i, i + maxConsecutive);
      if (_isConsecutiveNumbers(sequence) || _isConsecutiveLetters(sequence)) {
        warnings.add('تجنب الأحرف أو الأرقام المتتالية');
        break;
      }
    }
  }

  /// Vérifie les caractères répétés (aaa, 111, etc.)
  void _checkRepeatedCharacters(String password, List<String> warnings) {
    final maxRepeated = _passwordRules['maxRepeatedChars'] as int;

    if (password.length <= maxRepeated) return;

    for (int i = 0; i <= password.length - (maxRepeated + 1); i++) {
      String sequence = password.substring(i, i + maxRepeated + 1);
      if (_isRepeatedCharacters(sequence)) {
        warnings.add('تجنب تكرار نفس الحرف عدة مرات');
        break;
      }
    }
  }

  /// Vérifie les motifs de clavier courants (qwerty, asdf, etc.)
  void _checkKeyboardPatterns(String password, List<String> warnings) {
    final keyboardPatterns = [
      'qwerty',
      'asdf',
      'zxcv',
      'qwertyuiop',
      'asdfghjkl',
      'zxcvbnm',
      '123456789',
      'abcdefghijklmnopqrstuvwxyz',
    ];

    final lowerPassword = password.toLowerCase();
    for (String pattern in keyboardPatterns) {
      if (lowerPassword.contains(pattern)) {
        warnings.add('تجنب أنماط لوحة المفاتيح الشائعة');
        break;
      }
    }
  }

  /// Vérifie les informations personnelles potentielles
  void _checkPersonalInfo(String password, List<String> warnings) {
    // Cette méthode pourrait être étendue pour vérifier contre
    // les informations utilisateur connues (nom, email, etc.)
    final personalPatterns = [
      RegExp(r'\d{4}'), // Années (1985, 1990, etc.)
      RegExp(r'\d{2}/\d{2}'), // Dates (12/25, 01/01, etc.)
    ];

    for (RegExp pattern in personalPatterns) {
      if (pattern.hasMatch(password)) {
        warnings.add('تجنب استخدام التواريخ أو السنوات الشخصية');
        break;
      }
    }
  }

  /// Génère des suggestions d'amélioration
  List<String> _generateSuggestions(String password) {
    List<String> suggestions = [];

    if (password.length < 8) {
      suggestions.add('أضف المزيد من الأحرف');
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      suggestions.add('أضف حروف كبيرة');
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      suggestions.add('أضف حروف صغيرة');
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      suggestions.add('أضف أرقام');
    }

    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      suggestions.add('أضف رموز خاصة');
    }

    if (password.length < 12) {
      suggestions.add('جعل كلمة المرور أطول (12+ حرف)');
    }

    return suggestions;
  }

  /// Vérifie si une séquence est constituée de chiffres consécutifs
  bool _isConsecutiveNumbers(String sequence) {
    for (int i = 1; i < sequence.length; i++) {
      if (sequence.codeUnitAt(i) != sequence.codeUnitAt(i - 1) + 1) {
        return false;
      }
    }
    return sequence.length >= 3 && RegExp(r'^\d+$').hasMatch(sequence);
  }

  /// Vérifie si une séquence est constituée de lettres consécutives
  bool _isConsecutiveLetters(String sequence) {
    for (int i = 1; i < sequence.length; i++) {
      if (sequence.codeUnitAt(i) != sequence.codeUnitAt(i - 1) + 1) {
        return false;
      }
    }
    return sequence.length >= 3 && RegExp(r'^[a-zA-Z]+$').hasMatch(sequence);
  }

  /// Vérifie si une séquence contient des caractères répétés
  bool _isRepeatedCharacters(String sequence) {
    if (sequence.length < 3) return false;

    String firstChar = sequence[0];
    for (int i = 1; i < sequence.length; i++) {
      if (sequence[i] != firstChar) {
        return false;
      }
    }
    return true;
  }

  /// Valide un mot de passe avec un historique (pour éviter la réutilisation)
  PasswordValidationResult validatePasswordWithHistory(
    String password,
    List<String> passwordHistory,
  ) {
    PasswordValidationResult result = validatePassword(password);

    // Vérifier l'historique
    for (String oldPassword in passwordHistory) {
      if (_calculateSimilarity(password, oldPassword) > 0.8) {
        result.errors.add('كلمة المرور مشابهة جداً لكلمة مرور سابقة');
        break;
      }
    }

    return result;
  }

  /// Calcule la similarité entre deux mots de passe
  double _calculateSimilarity(String password1, String password2) {
    if (password1 == password2) return 1.0;

    int commonChars = 0;
    int maxLength =
        password1.length > password2.length
            ? password1.length
            : password2.length;

    for (int i = 0; i < maxLength; i++) {
      if (i < password1.length &&
          i < password2.length &&
          password1[i] == password2[i]) {
        commonChars++;
      }
    }

    return commonChars / maxLength;
  }

  /// Génère un mot de passe sécurisé (pour les tests ou l'auto-génération)
  String generateSecurePassword({
    int length = 12,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSpecialChars = true,
  }) {
    String chars = '';

    if (includeLowercase) chars += 'abcdefghijklmnopqrstuvwxyz';
    if (includeUppercase) chars += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (includeNumbers) chars += '0123456789';
    if (includeSpecialChars) chars += '!@#\$%^&*()_+-=[]{}|;:,.<>?';

    if (chars.isEmpty)
      chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

    String password = '';
    final random = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < length; i++) {
      password += chars[random % chars.length];
    }

    // S'assurer que le mot de passe généré respecte toutes les règles
    PasswordValidationResult validation = validatePassword(password);
    if (!validation.isValid) {
      return generateSecurePassword(
        length: length,
        includeUppercase: includeUppercase,
        includeLowercase: includeLowercase,
        includeNumbers: includeNumbers,
        includeSpecialChars: includeSpecialChars,
      );
    }

    return password;
  }
}
