import 'package:flutter/material.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import 'ui_components.dart';

/// Mot à saisir pour confirmer la suppression définitive du compte.
const String _confirmationWord = 'حذف';

/// Demande confirmation puis supprime définitivement le compte connecté.
/// En cas de succès, l'utilisateur est déconnecté et renvoyé vers /login.
Future<void> confirmAndDeleteAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
  if (confirmed != true || !context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  final error = await AuthService().deleteAccount();
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  if (error != null) {
    ModernDialog.showError(context, title: 'خطأ', message: error);
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('تم حذف حسابك بنجاح'),
      backgroundColor: AppTheme.successColor,
    ),
  );
  context.go('/login');
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _controller.text.trim() == _confirmationWord;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.delete_forever_rounded, color: AppTheme.errorColor),
          SizedBox(width: 8),
          Flexible(child: Text('حذف الحساب')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'سيتم حذف حسابك وجميع بياناتك نهائياً، ولا يمكن التراجع عن هذا الإجراء.',
          ),
          const SizedBox(height: 16),
          const Text('اكتب "$_confirmationWord" للتأكيد:'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: _confirmationWord,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: canConfirm ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
          child: const Text('حذف نهائياً'),
        ),
      ],
    );
  }
}
