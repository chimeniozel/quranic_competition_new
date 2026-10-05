import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/app_version_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/store_version_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../models/app_settings.dart';

/// Écran d'administration de la mise à jour forcée.
///
/// Chaque plateforme a son propre build number et son propre lien de
/// téléchargement : ils progressent indépendamment et ne sont jamais
/// comparables entre eux.
class ForceUpdatePage extends StatefulWidget {
  const ForceUpdatePage({super.key});

  @override
  State<ForceUpdatePage> createState() => _ForceUpdatePageState();
}

class _ForceUpdatePageState extends State<ForceUpdatePage> {
  final _formKey = GlobalKey<FormState>();
  final AppVersionService _service = AppVersionService();
  final PermissionService _permissionService = PermissionService();
  final StoreVersionService _storeService = StoreVersionService();

  final _androidVersionController = TextEditingController();
  final _iosVersionController = TextEditingController();
  final _androidBuildController = TextEditingController();
  final _iosBuildController = TextEditingController();
  final _androidUrlController = TextEditingController();
  final _iosUrlController = TextEditingController();
  final _messageController = TextEditingController();

  AppSettings? _settings;
  bool _forceUpdateEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  /// Build number de l'appareil courant, affiché comme repère : c'est celui
  /// que l'administrateur doit comparer à la valeur qu'il saisit.
  int? _currentBuild;
  String? _currentVersionName;

  /// Versions réellement publiées sur les stores, lues automatiquement.
  String? _storeVersionAndroid;
  String? _storeVersionIos;
  bool _isFetchingStoreVersions = false;

  /// Réglages avancés (build numbers) repliés par défaut.
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _androidVersionController.dispose();
    _iosVersionController.dispose();
    _androidBuildController.dispose();
    _iosBuildController.dispose();
    _androidUrlController.dispose();
    _iosUrlController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings = await _service.getSettings() ?? AppSettings.defaults();
      final packageInfo = await _service.getCurrentVersion();

      if (!mounted) return;
      setState(() {
        _settings = settings;
        _currentBuild = int.tryParse(packageInfo.buildNumber);
        _currentVersionName = packageInfo.version;
        _forceUpdateEnabled = settings.forceUpdateEnabled;
        _androidVersionController.text = settings.minimumVersionAndroid;
        _iosVersionController.text = settings.minimumVersionIos;
        _androidBuildController.text = settings.minimumBuildAndroid.toString();
        _iosBuildController.text = settings.minimumBuildIos.toString();
        _androidUrlController.text = settings.updateUrlAndroid;
        _iosUrlController.text = settings.updateUrlIos;
        _messageController.text = settings.updateMessage;
        _isLoading = false;
      });

      // Les versions publiées se chargent en arrière-plan : l'écran est déjà
      // utilisable sans elles.
      _fetchStoreVersions();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذّر تحميل الإعدادات. تحقق من الاتصال بالإنترنت.';
        _isLoading = false;
      });
    }
  }

  /// Interroge les stores pour connaître la version actuellement publiée.
  Future<void> _fetchStoreVersions() async {
    setState(() => _isFetchingStoreVersions = true);

    final results = await Future.wait([
      _storeService.fetchAndroidVersion(),
      _storeService.fetchIosVersion(),
    ]);

    if (!mounted) return;
    setState(() {
      _storeVersionAndroid = results[0];
      _storeVersionIos = results[1];
      _isFetchingStoreVersions = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final canModify = await _permissionService.canModify();
    if (!mounted) return;
    if (!canModify) {
      _showMessage('ليس لديك صلاحية تعديل الإعدادات', isError: true);
      return;
    }

    // Bloquer tout le monde est une action à confirmer explicitement.
    if (_forceUpdateEnabled) {
      final confirmed = await _confirmBlockingUsers();
      if (confirmed != true) return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = (_settings ?? AppSettings.defaults()).copyWith(
        forceUpdateEnabled: _forceUpdateEnabled,
        minimumVersionAndroid: _androidVersionController.text.trim(),
        minimumVersionIos: _iosVersionController.text.trim(),
        minimumBuildAndroid: int.parse(_androidBuildController.text.trim()),
        minimumBuildIos: int.parse(_iosBuildController.text.trim()),
        updateUrlAndroid: _androidUrlController.text.trim(),
        updateUrlIos: _iosUrlController.text.trim(),
        updateMessage: _messageController.text.trim(),
      );

      await _service.saveSettings(updated);

      if (!mounted) return;
      setState(() {
        _settings = updated;
        _isSaving = false;
      });
      _showMessage('تم حفظ الإعدادات بنجاح');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('تعذّر حفظ الإعدادات: $e', isError: true);
    }
  }

  Future<bool?> _confirmBlockingUsers() {
    final platformBuild =
        Platform.isIOS
            ? (_iosVersionController.text.trim().isNotEmpty
                ? _iosVersionController.text.trim()
                : _iosBuildController.text.trim())
            : (_androidVersionController.text.trim().isNotEmpty
                ? _androidVersionController.text.trim()
                : _androidBuildController.text.trim());

    return ModernDialog.showConfirm(
      context,
      title: 'تأكيد التحديث الإجباري',
      message:
          'سيُمنع كل مستخدم رقم بنائه أقل من المطلوب من استعمال التطبيق '
          'حتى يُحدّثه.\n\nتأكد من أن النسخة الجديدة منشورة فعلاً في المتجر '
          'قبل التفعيل، وأن الحد الأدنى المطلوب ($platformBuild) صحيح.',
      cancelText: 'إلغاء',
      confirmText: 'تفعيل',
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
      ),
    );
  }

  /// Le champ peut rester vide : on retombe alors sur le build number.
  String? _validateVersionName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    if (!RegExp(r'^\d+(\.\d+)*$').hasMatch(text)) {
      return 'أدخل رقم نسخة مثل 8.3.0';
    }
    return null;
  }

  String? _validateBuild(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'رقم البناء مطلوب';

    final number = int.tryParse(text);
    if (number == null) return 'أدخل رقمًا صحيحًا';
    if (number < 1) return 'يجب أن يكون الرقم 1 أو أكثر';
    return null;
  }

  String? _validateUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'الرابط مطلوب';

    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || !uri.host.contains('.')) {
      return 'أدخل رابطًا صحيحًا يبدأ بـ https://';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'التحديث الإجباري'),
      body:
          _isLoading
              ? const ModernLoadingIndicator(message: 'جاري تحميل الإعدادات...')
              : _errorMessage != null
              ? EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'تعذّر تحميل الإعدادات',
                subtitle: _errorMessage,
                iconColor: AppTheme.errorColor,
                action: PrimaryButton(text: 'إعادة المحاولة', onPressed: _load),
              )
              : ModernPullToRefresh(
                onRefresh: _load,
                child: Form(
                  key: _formKey,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: AppTheme.spacingS),
                      _buildMinimumVersionCard(),
                      const SizedBox(height: AppTheme.spacingS),
                      _buildAdvancedCard(),
                      const SizedBox(height: AppTheme.spacingS),
                      _buildUrlsCard(),
                      const SizedBox(height: AppTheme.spacingS),
                      _buildMessageCard(),
                      const SizedBox(height: AppTheme.spacingL),
                      PrimaryButton(
                        text: _isSaving ? 'جاري الحفظ...' : 'حفظ الإعدادات',
                        onPressed: _isSaving ? null : _save,
                      ),
                      const SizedBox(height: AppTheme.spacingXL),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildStatusCard() {
    final isOn = _forceUpdateEnabled;
    final color = isOn ? AppTheme.warningColor : AppTheme.textSecondaryColor;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOn ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التحديث الإجباري',
                      style: AppTheme.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOn
                          ? 'مفعّل: النسخ الأقدم لا يمكنها استعمال التطبيق'
                          : 'معطّل: كل النسخ تعمل بشكل طبيعي',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isOn,
                activeThumbColor: AppTheme.warningColor,
                onChanged:
                    (value) => setState(() => _forceUpdateEnabled = value),
              ),
            ],
          ),
          if (_currentBuild != null) ...[
            const Divider(height: AppTheme.spacingL),
            Row(
              children: [
                Icon(
                  Icons.phone_iphone_rounded,
                  size: 18,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(width: AppTheme.spacingXS),
                Expanded(
                  child: Text(
                    'نسخة هذا الجهاز (${Platform.isIOS ? 'iOS' : 'Android'}): '
                    '${_currentVersionName ?? '—'} (بناء $_currentBuild)',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMinimumVersionCard() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.verified_rounded,
            title: 'الحد الأدنى للنسخة',
            subtitle:
                'كل مستخدم نسخته أقدم من هذا الرقم سيُطالَب بالتحديث. '
                'النسخة المنشورة تُقرأ من المتجر تلقائيًا.',
          ),
          const SizedBox(height: AppTheme.spacingS),
          _buildPlatformRow(
            label: 'Android',
            icon: Icons.android_rounded,
            controller: _androidVersionController,
            storeVersion: _storeVersionAndroid,
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildPlatformRow(
            label: 'iOS',
            icon: Icons.apple_rounded,
            controller: _iosVersionController,
            storeVersion: _storeVersionIos,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _isFetchingStoreVersions ? null : _fetchStoreVersions,
              icon:
                  _isFetchingStoreVersions
                      ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                _isFetchingStoreVersions
                    ? 'جاري قراءة المتاجر...'
                    : 'تحديث النسخ المنشورة',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ligne d'une plateforme : version publiée détectée + champ du minimum.
  Widget _buildPlatformRow({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String? storeVersion,
  }) {
    final hasStoreVersion = storeVersion != null && storeVersion.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondaryColor),
            const SizedBox(width: AppTheme.spacingXS),
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Text(
                _isFetchingStoreVersions
                    ? 'جاري القراءة...'
                    : hasStoreVersion
                    ? 'المنشورة في المتجر: $storeVersion'
                    : 'تعذّرت قراءة النسخة المنشورة',
                style: AppTheme.bodySmall.copyWith(
                  color:
                      hasStoreVersion
                          ? AppTheme.successColor
                          : AppTheme.textSecondaryColor,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingXS),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'الحد الأدنى — $label',
                  hintText: '8.3.0',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                ),
                validator: _validateVersionName,
              ),
            ),
            if (hasStoreVersion) ...[
              const SizedBox(width: AppTheme.spacingXS),
              // Un seul geste remplace la saisie manuelle du numéro
              OutlinedButton(
                onPressed: () {
                  setState(() => controller.text = storeVersion);
                },
                child: const Text('استعمل المنشورة'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Réglage hérité : utile uniquement pour les applications déjà installées
  /// qui ne comparent que le build number.
  Widget _buildAdvancedCard() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            child: Row(
              children: [
                Expanded(
                  child: _buildSectionTitle(
                    icon: Icons.tune_rounded,
                    title: 'إعدادات متقدمة (أرقام البناء)',
                    subtitle:
                        'تُستعمل فقط إن تُرك الحد الأدنى للنسخة فارغًا، '
                        'ومع النسخ القديمة المثبّتة.',
                  ),
                ),
                Icon(
                  _showAdvanced ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppTheme.textSecondaryColor,
                ),
              ],
            ),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: AppTheme.spacingS),
            _buildTextField(
              controller: _androidBuildController,
              label: 'رقم البناء المطلوب — Android',
              icon: Icons.android_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _validateBuild,
            ),
            const SizedBox(height: AppTheme.spacingS),
            _buildTextField(
              controller: _iosBuildController,
              label: 'رقم البناء المطلوب — iOS',
              icon: Icons.apple_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _validateBuild,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUrlsCard() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.link_rounded,
            title: 'روابط التحميل',
            subtitle:
                'يُفتح الرابط المناسب لمنصّة المستخدم عند الضغط على زر التحديث.',
          ),
          const SizedBox(height: AppTheme.spacingS),
          _buildTextField(
            controller: _androidUrlController,
            label: 'رابط نسخة Android',
            icon: Icons.android_rounded,
            keyboardType: TextInputType.url,
            validator: _validateUrl,
            suffixIcon: _buildCopyButton(
              controller: _androidUrlController,
              label: 'رابط Android',
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          _buildTextField(
            controller: _iosUrlController,
            label: 'رابط نسخة iOS',
            icon: Icons.apple_rounded,
            keyboardType: TextInputType.url,
            validator: _validateUrl,
            suffixIcon: _buildCopyButton(
              controller: _iosUrlController,
              label: 'رابط iOS',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.message_rounded,
            title: 'رسالة التحديث',
            subtitle: 'النص الذي يظهر للمستخدم في نافذة التحديث.',
          ),
          const SizedBox(height: AppTheme.spacingS),
          TextFormField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: AppSettings.defaultMessage,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'الرسالة مطلوبة';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  /// Copie le lien dans le presse-papiers, pour le coller ailleurs sans
  /// avoir à le sélectionner à la main.
  Widget _buildCopyButton({
    required TextEditingController controller,
    required String label,
  }) {
    return IconButton(
      tooltip: 'نسخ $label',
      icon: const Icon(Icons.copy_rounded, size: 20),
      onPressed: () async {
        final value = controller.text.trim();
        if (value.isEmpty) {
          _showMessage('الحقل فارغ، لا يوجد ما يُنسخ', isError: true);
          return;
        }

        await Clipboard.setData(ClipboardData(text: value));
        if (!mounted) return;
        _showMessage('تم نسخ $label');
      },
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: AppTheme.spacingXS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textDirection:
          keyboardType == TextInputType.number ? TextDirection.ltr : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
      ),
      validator: validator,
    );
  }
}
