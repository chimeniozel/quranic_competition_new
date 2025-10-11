/// Service centralisé pour la gestion des erreurs et messages
/// Fournit des messages d'erreur en arabe et des codes d'erreur standardisés
class ErrorService {
  static final ErrorService _instance = ErrorService._internal();
  factory ErrorService() => _instance;
  ErrorService._internal();

  /// Messages d'erreur en arabe organisés par catégorie
  static const Map<String, Map<String, String>> _errorMessages = {
    'auth': {
      'invalid_credentials': 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
      'email_already_exists': 'البريد الإلكتروني مستخدم بالفعل',
      'phone_already_exists': 'رقم الهاتف مستخدم بالفعل',
      'weak_password': 'كلمة المرور ضعيفة جداً',
      'invalid_email': 'البريد الإلكتروني غير صالح',
      'invalid_phone': 'رقم الهاتف غير صالح',
      'user_not_found': 'المستخدم غير موجود',
      'account_not_verified': 'الحساب غير موثق',
      'account_already_verified': 'الحساب موثق بالفعل',
      'verification_failed': 'فشل في التحقق من الهوية',
      'session_expired': 'انتهت صلاحية الجلسة',
      'permission_denied': 'ليس لديك صلاحية للوصول',
      'too_many_attempts': 'عدد كبير من المحاولات، حاول مرة أخرى لاحقاً',
      'network_error': 'خطأ في الشبكة، تحقق من الاتصال',
      'server_error': 'خطأ في الخادم، حاول مرة أخرى',
      'unknown_error': 'حدث خطأ غير متوقع',
    },
    'validation': {
      'required_field': 'هذا الحقل مطلوب',
      'invalid_format': 'التنسيق غير صحيح',
      'too_short': 'النص قصير جداً',
      'too_long': 'النص طويل جداً',
      'invalid_length': 'الطول غير صحيح',
      'special_characters': 'يحتوي على أحرف غير مسموحة',
      'numbers_only': 'يجب أن يحتوي على أرقام فقط',
      'letters_only': 'يجب أن يحتوي على أحرف فقط',
      'mixed_content': 'يجب أن يحتوي على أحرف وأرقام',
    },
    'database': {
      'connection_failed': 'فشل الاتصال بقاعدة البيانات',
      'query_failed': 'فشل في تنفيذ الاستعلام',
      'data_not_found': 'البيانات غير موجودة',
      'duplicate_entry': 'البيانات موجودة بالفعل',
      'constraint_violation': 'انتهاك قواعد البيانات',
      'transaction_failed': 'فشل في المعاملة',
      'backup_failed': 'فشل في النسخ الاحتياطي',
    },
    'file': {
      'file_not_found': 'الملف غير موجود',
      'file_too_large': 'حجم الملف كبير جداً',
      'invalid_format': 'تنسيق الملف غير مدعوم',
      'upload_failed': 'فشل في رفع الملف',
      'download_failed': 'فشل في تحميل الملف',
      'permission_denied': 'ليس لديك صلاحية للوصول للملف',
    },
    'network': {
      'connection_timeout': 'انتهت مهلة الاتصال',
      'no_internet': 'لا يوجد اتصال بالإنترنت',
      'server_unavailable': 'الخادم غير متاح',
      'request_failed': 'فشل في الطلب',
      'response_invalid': 'استجابة غير صحيحة',
    },
    'user_management': {
      'user_creation_failed': 'فشل في إنشاء المستخدم',
      'user_update_failed': 'فشل في تحديث المستخدم',
      'user_deletion_failed': 'فشل في حذف المستخدم',
      'role_assignment_failed': 'فشل في تعيين الدور',
      'permission_grant_failed': 'فشل في منح الصلاحية',
      'user_already_exists': 'المستخدم موجود بالفعل',
      'invalid_role': 'الدور غير صحيح',
    },
  };

  /// Codes d'erreur standardisés
  static const Map<String, String> _errorCodes = {
    'AUTH_INVALID_CREDENTIALS': 'auth.invalid_credentials',
    'AUTH_EMAIL_EXISTS': 'auth.email_already_exists',
    'AUTH_PHONE_EXISTS': 'auth.phone_already_exists',
    'AUTH_WEAK_PASSWORD': 'auth.weak_password',
    'AUTH_INVALID_EMAIL': 'auth.invalid_email',
    'AUTH_INVALID_PHONE': 'auth.invalid_phone',
    'AUTH_USER_NOT_FOUND': 'auth.user_not_found',
    'AUTH_ACCOUNT_NOT_VERIFIED': 'auth.account_not_verified',
    'AUTH_SESSION_EXPIRED': 'auth.session_expired',
    'AUTH_PERMISSION_DENIED': 'auth.permission_denied',
    'AUTH_TOO_MANY_ATTEMPTS': 'auth.too_many_attempts',
    'NETWORK_ERROR': 'network.connection_timeout',
    'SERVER_ERROR': 'auth.server_error',
    'UNKNOWN_ERROR': 'auth.unknown_error',

    'VALIDATION_REQUIRED': 'validation.required_field',
    'VALIDATION_INVALID_FORMAT': 'validation.invalid_format',
    'VALIDATION_TOO_SHORT': 'validation.too_short',
    'VALIDATION_TOO_LONG': 'validation.too_long',

    'DATABASE_CONNECTION_FAILED': 'database.connection_failed',
    'DATABASE_QUERY_FAILED': 'database.query_failed',
    'DATABASE_DATA_NOT_FOUND': 'database.data_not_found',
    'DATABASE_DUPLICATE_ENTRY': 'database.duplicate_entry',

    'FILE_NOT_FOUND': 'file.file_not_found',
    'FILE_TOO_LARGE': 'file.file_too_large',
    'FILE_UPLOAD_FAILED': 'file.upload_failed',

    'USER_CREATION_FAILED': 'user_management.user_creation_failed',
    'USER_UPDATE_FAILED': 'user_management.user_update_failed',
    'USER_DELETION_FAILED': 'user_management.user_deletion_failed',
    'USER_ALREADY_EXISTS': 'user_management.user_already_exists',
  };

  /// Obtient un message d'erreur en arabe à partir d'un code d'erreur
  String getErrorMessage(String errorCode) {
    final messageKey = _errorCodes[errorCode];
    if (messageKey == null) {
      return _errorMessages['auth']!['unknown_error']!;
    }

    final parts = messageKey.split('.');
    if (parts.length != 2) {
      return _errorMessages['auth']!['unknown_error']!;
    }

    final category = parts[0];
    final key = parts[1];

    return _errorMessages[category]?[key] ??
        _errorMessages['auth']!['unknown_error']!;
  }

  /// Obtient un message d'erreur personnalisé avec des paramètres
  String getErrorMessageWithParams(
    String errorCode,
    Map<String, String> params,
  ) {
    String message = getErrorMessage(errorCode);

    params.forEach((key, value) {
      message = message.replaceAll('{$key}', value);
    });

    return message;
  }

  /// Analyse une exception et retourne un message d'erreur approprié
  String analyzeException(dynamic exception) {
    if (exception == null) {
      return getErrorMessage('UNKNOWN_ERROR');
    }

    final errorString = exception.toString().toLowerCase();

    // Erreurs d'authentification Supabase
    if (errorString.contains('invalid login credentials')) {
      return getErrorMessage('AUTH_INVALID_CREDENTIALS');
    }
    if (errorString.contains('user already registered')) {
      return getErrorMessage('AUTH_EMAIL_EXISTS');
    }
    if (errorString.contains('weak password')) {
      return getErrorMessage('AUTH_WEAK_PASSWORD');
    }
    if (errorString.contains('invalid email')) {
      return getErrorMessage('AUTH_INVALID_EMAIL');
    }
    if (errorString.contains('user not found')) {
      return getErrorMessage('AUTH_USER_NOT_FOUND');
    }
    if (errorString.contains('email not confirmed')) {
      return getErrorMessage('AUTH_ACCOUNT_NOT_VERIFIED');
    }
    if (errorString.contains('session not found')) {
      return getErrorMessage('AUTH_SESSION_EXPIRED');
    }
    if (errorString.contains('permission denied')) {
      return getErrorMessage('AUTH_PERMISSION_DENIED');
    }

    // Erreurs de réseau
    if (errorString.contains('connection timeout') ||
        errorString.contains('network')) {
      return getErrorMessage('NETWORK_ERROR');
    }
    if (errorString.contains('server error') || errorString.contains('500')) {
      return getErrorMessage('SERVER_ERROR');
    }

    // Erreurs de base de données
    if (errorString.contains('database') || errorString.contains('sql')) {
      return getErrorMessage('DATABASE_CONNECTION_FAILED');
    }
    if (errorString.contains('duplicate') ||
        errorString.contains('already exists')) {
      return getErrorMessage('DATABASE_DUPLICATE_ENTRY');
    }
    if (errorString.contains('not found') || errorString.contains('no data')) {
      return getErrorMessage('DATABASE_DATA_NOT_FOUND');
    }

    // Erreurs de fichier
    if (errorString.contains('file not found')) {
      return getErrorMessage('FILE_NOT_FOUND');
    }
    if (errorString.contains('file too large')) {
      return getErrorMessage('FILE_TOO_LARGE');
    }

    // Par défaut
    return getErrorMessage('UNKNOWN_ERROR');
  }

  /// Valide et retourne un message d'erreur pour les champs de formulaire
  String validateField(
    String fieldName,
    String value,
    Map<String, dynamic> rules,
  ) {
    // Vérifier si le champ est requis
    if (rules['required'] == true && (value.isEmpty || value.trim().isEmpty)) {
      return getErrorMessage('VALIDATION_REQUIRED');
    }

    if (value.isEmpty) return ''; // Pas d'erreur si le champ n'est pas requis

    // Vérifier la longueur minimale
    if (rules['minLength'] != null && value.length < rules['minLength']) {
      return getErrorMessageWithParams('VALIDATION_TOO_SHORT', {
        'min': rules['minLength'].toString(),
      });
    }

    // Vérifier la longueur maximale
    if (rules['maxLength'] != null && value.length > rules['maxLength']) {
      return getErrorMessageWithParams('VALIDATION_TOO_LONG', {
        'max': rules['maxLength'].toString(),
      });
    }

    // Validation spécifique par type de champ
    switch (fieldName.toLowerCase()) {
      case 'email':
        if (!_isValidEmail(value)) {
          return getErrorMessage('AUTH_INVALID_EMAIL');
        }
        break;
      case 'phone':
        if (!_isValidPhone(value)) {
          return getErrorMessage('AUTH_INVALID_PHONE');
        }
        break;
      case 'password':
        if (!_isValidPassword(value)) {
          return getErrorMessage('AUTH_WEAK_PASSWORD');
        }
        break;
    }

    return ''; // Pas d'erreur
  }

  /// Valide un email
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Valide un numéro de téléphone
  bool _isValidPhone(String phone) {
    return RegExp(r'^\+?[\d\s\-\(\)]{8,15}$').hasMatch(phone);
  }

  /// Valide un mot de passe
  bool _isValidPassword(String password) {
    // Au moins 8 caractères, une majuscule, une minuscule, un chiffre
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }

  /// Messages de succès en arabe
  static const Map<String, String> _successMessages = {
    'login_success': 'تم تسجيل الدخول بنجاح',
    'signup_success': 'تم التسجيل بنجاح',
    'logout_success': 'تم تسجيل الخروج بنجاح',
    'profile_updated': 'تم تحديث الملف الشخصي بنجاح',
    'password_changed': 'تم تغيير كلمة المرور بنجاح',
    'account_verified': 'تم التحقق من الحساب بنجاح',
    'user_created': 'تم إنشاء المستخدم بنجاح',
    'user_updated': 'تم تحديث المستخدم بنجاح',
    'user_deleted': 'تم حذف المستخدم بنجاح',
    'role_assigned': 'تم تعيين الدور بنجاح',
    'permission_granted': 'تم منح الصلاحية بنجاح',
    'file_uploaded': 'تم رفع الملف بنجاح',
    'data_saved': 'تم حفظ البيانات بنجاح',
  };

  /// Obtient un message de succès
  String getSuccessMessage(String key) {
    return _successMessages[key] ?? 'تم العمل بنجاح';
  }
}
