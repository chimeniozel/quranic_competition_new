/// Paramètres de mise à jour forcée (table `app_settings`, ligne unique).
class AppSettings {
  final String? id;

  /// Mise à jour forcée activée ou non.
  final bool forceUpdateEnabled;

  /// Version minimale exigée, par plateforme (« 8.3.0 »).
  ///
  /// C'est le réglage principal : les stores publient un numéro de version,
  /// jamais le build number, ce qui permet de le remplir automatiquement.
  /// Vide = non défini, on retombe alors sur le build number.
  final String minimumVersionAndroid;
  final String minimumVersionIos;

  /// Build number minimal exigé, par plateforme.
  ///
  /// Conservé pour les applications déjà installées qui ne connaissent que
  /// cette comparaison.
  final int minimumBuildAndroid;
  final int minimumBuildIos;

  /// Liens de téléchargement présentés à l'utilisateur bloqué.
  final String updateUrlAndroid;
  final String updateUrlIos;

  /// Message affiché dans la boîte de dialogue.
  final String updateMessage;

  const AppSettings({
    this.id,
    required this.forceUpdateEnabled,
    required this.minimumVersionAndroid,
    required this.minimumVersionIos,
    required this.minimumBuildAndroid,
    required this.minimumBuildIos,
    required this.updateUrlAndroid,
    required this.updateUrlIos,
    required this.updateMessage,
  });

  static const String defaultAndroidUrl =
      'https://play.google.com/store/apps/details?id=com.chemeni.quranic_competition';
  static const String defaultIosUrl = 'https://apps.apple.com/app/id6739760516';
  static const String defaultMessage =
      'يجب تحديث التطبيق إلى أحدث إصدار للاستمرار في الاستخدام.';

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    // `minimum_version_code` est l'ancienne colonne commune aux deux
    // plateformes : elle sert de valeur de repli tant que les colonnes par
    // plateforme ne sont pas renseignées.
    final legacyMinimum = (map['minimum_version_code'] as num?)?.toInt() ?? 1;

    return AppSettings(
      id: map['id'] as String?,
      forceUpdateEnabled: map['force_update_enabled'] as bool? ?? false,
      minimumVersionAndroid:
          (map['minimum_version_name_android'] as String?)?.trim() ?? '',
      minimumVersionIos:
          (map['minimum_version_name_ios'] as String?)?.trim() ?? '',
      minimumBuildAndroid:
          (map['minimum_version_code_android'] as num?)?.toInt() ??
          legacyMinimum,
      minimumBuildIos:
          (map['minimum_version_code_ios'] as num?)?.toInt() ?? legacyMinimum,
      updateUrlAndroid:
          (map['update_url_android'] as String?)?.trim().isNotEmpty == true
              ? (map['update_url_android'] as String).trim()
              : defaultAndroidUrl,
      updateUrlIos:
          (map['update_url_ios'] as String?)?.trim().isNotEmpty == true
              ? (map['update_url_ios'] as String).trim()
              : defaultIosUrl,
      updateMessage:
          (map['update_message'] as String?)?.trim().isNotEmpty == true
              ? (map['update_message'] as String).trim()
              : defaultMessage,
    );
  }

  factory AppSettings.defaults() => const AppSettings(
    forceUpdateEnabled: false,
    minimumVersionAndroid: '',
    minimumVersionIos: '',
    minimumBuildAndroid: 1,
    minimumBuildIos: 1,
    updateUrlAndroid: defaultAndroidUrl,
    updateUrlIos: defaultIosUrl,
    updateMessage: defaultMessage,
  );

  Map<String, dynamic> toMap() {
    return {
      'force_update_enabled': forceUpdateEnabled,
      'minimum_version_name_android': minimumVersionAndroid,
      'minimum_version_name_ios': minimumVersionIos,
      'minimum_version_code_android': minimumBuildAndroid,
      'minimum_version_code_ios': minimumBuildIos,
      // Colonne historique tenue à jour pour les versions de l'application
      // qui la lisent encore.
      'minimum_version_code':
          minimumBuildAndroid > minimumBuildIos
              ? minimumBuildIos
              : minimumBuildAndroid,
      'update_url_android': updateUrlAndroid,
      'update_url_ios': updateUrlIos,
      'update_message': updateMessage,
    };
  }

  AppSettings copyWith({
    bool? forceUpdateEnabled,
    String? minimumVersionAndroid,
    String? minimumVersionIos,
    int? minimumBuildAndroid,
    int? minimumBuildIos,
    String? updateUrlAndroid,
    String? updateUrlIos,
    String? updateMessage,
  }) {
    return AppSettings(
      id: id,
      forceUpdateEnabled: forceUpdateEnabled ?? this.forceUpdateEnabled,
      minimumVersionAndroid:
          minimumVersionAndroid ?? this.minimumVersionAndroid,
      minimumVersionIos: minimumVersionIos ?? this.minimumVersionIos,
      minimumBuildAndroid: minimumBuildAndroid ?? this.minimumBuildAndroid,
      minimumBuildIos: minimumBuildIos ?? this.minimumBuildIos,
      updateUrlAndroid: updateUrlAndroid ?? this.updateUrlAndroid,
      updateUrlIos: updateUrlIos ?? this.updateUrlIos,
      updateMessage: updateMessage ?? this.updateMessage,
    );
  }
}
