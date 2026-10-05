import 'package:flutter/material.dart';
import '../services/password_validation_service.dart';
import '../services/error_service.dart';
import '../theme/app_theme.dart';

/// Widget réutilisable pour les champs de mot de passe avec validation avancée
class PasswordFieldWidget extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;
  final bool showStrengthIndicator;
  final bool showSuggestions;
  final List<String>? passwordHistory;
  final VoidCallback? onChanged;

  const PasswordFieldWidget({
    super.key,
    required this.controller,
    this.labelText = 'كلمة المرور',
    this.validator,
    this.showStrengthIndicator = true,
    this.showSuggestions = true,
    this.passwordHistory,
    this.onChanged,
  });

  @override
  State<PasswordFieldWidget> createState() => _PasswordFieldWidgetState();
}

class _PasswordFieldWidgetState extends State<PasswordFieldWidget> {
  final PasswordValidationService _passwordService =
      PasswordValidationService();
  final ErrorService _errorService = ErrorService();

  bool _obscurePassword = true;
  bool _showValidation = false;
  PasswordValidationResult? _validationResult;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPasswordChanged);
    super.dispose();
  }

  void _onPasswordChanged() {
    if (mounted) {
      setState(() {
        _validationResult = _passwordService.validatePassword(
          widget.controller.text,
        );
        _showValidation = widget.controller.text.isNotEmpty;
      });
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Champ de mot de passe
        SizedBox(
          height: 56,
          child: TextFormField(
            controller: widget.controller,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: 'أدخل ${widget.labelText.toLowerCase()}',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.controller.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        _validationResult?.isValid == true
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
                        size: 20,
                        color:
                            _validationResult?.isValid == true
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                      ),
                      onPressed: null,
                    ),
                  IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                borderSide: const BorderSide(color: AppTheme.errorColor),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                borderSide: const BorderSide(
                  color: AppTheme.errorColor,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingS,
                vertical: AppTheme.spacingS,
              ),
            ),
            validator: widget.validator ?? _defaultValidator,
          ),
        ),

        // Indicateur de force et validation
        if (_showValidation && widget.showStrengthIndicator) ...[
          const SizedBox(height: 8),
          _buildValidationIndicator(),
        ],

        // Suggestions d'amélioration
        if (_showValidation &&
            widget.showSuggestions &&
            _validationResult != null &&
            !_validationResult!.isValid) ...[
          const SizedBox(height: 8),
          _buildSuggestions(),
        ],
      ],
    );
  }

  /// Validateur par défaut
  String? _defaultValidator(String? value) {
    if (value == null || value.isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }

    if (_validationResult != null && !_validationResult!.isValid) {
      return _validationResult!.errors.first;
    }

    return null;
  }

  /// Construit l'indicateur de validation
  Widget _buildValidationIndicator() {
    if (_validationResult == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            _validationResult!.isValid
                ? AppTheme.successColor.withValues(alpha: 0.08)
                : AppTheme.errorColor.withValues(alpha: 0.08),
        border: Border.all(
          color:
              _validationResult!.isValid
                  ? AppTheme.successColor.withValues(alpha: 0.3)
                  : AppTheme.errorColor.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barre de force
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: _validationResult!.strength / 10,
                  backgroundColor: AppTheme.dividerColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _validationResult!.strengthColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _validationResult!.strengthText,
                style: TextStyle(
                  color: _validationResult!.strengthColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          // Messages d'erreur
          if (_validationResult!.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...(_validationResult!.errors.map(
              (error) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.errorColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],

          // Avertissements
          if (_validationResult!.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...(_validationResult!.warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: AppTheme.warningColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(
                          color: AppTheme.warningColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  /// Construit les suggestions d'amélioration
  Widget _buildSuggestions() {
    if (_validationResult == null || _validationResult!.suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.infoColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: AppTheme.infoColor,
                size: 16,
              ),
              const SizedBox(width: 4),
              const Text(
                'اقتراحات للتحسين:',
                style: TextStyle(
                  color: AppTheme.infoColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...(_validationResult!.suggestions.map(
            (suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: AppTheme.infoColor)),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: const TextStyle(
                        color: AppTheme.infoColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

/// Widget pour le champ de confirmation de mot de passe
class ConfirmPasswordFieldWidget extends StatefulWidget {
  final TextEditingController controller;
  final TextEditingController passwordController;
  final String labelText;

  const ConfirmPasswordFieldWidget({
    super.key,
    required this.controller,
    required this.passwordController,
    this.labelText = 'تأكيد كلمة المرور',
  });

  @override
  State<ConfirmPasswordFieldWidget> createState() =>
      _ConfirmPasswordFieldWidgetState();
}

class _ConfirmPasswordFieldWidgetState
    extends State<ConfirmPasswordFieldWidget> {
  final ErrorService _errorService = ErrorService();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextFormField(
        controller: widget.controller,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: 'أدخل ${widget.labelText.toLowerCase()}',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            borderSide: const BorderSide(color: AppTheme.dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            borderSide: const BorderSide(color: AppTheme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            borderSide: const BorderSide(
              color: AppTheme.primaryColor,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            borderSide: const BorderSide(color: AppTheme.errorColor),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            borderSide: const BorderSide(color: AppTheme.errorColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingS,
            vertical: AppTheme.spacingS,
          ),
        ),
        validator: _validateConfirmPassword,
      ),
    );
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }

    if (value != widget.passwordController.text) {
      return 'كلمة المرور غير متطابقة';
    }

    return null;
  }
}
