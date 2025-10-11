import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/error_service.dart';
import '../../../core/widgets/password_field_widget.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _errorService = ErrorService();

  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();

  String _role = 'membre'; // Valeurs possibles: membre, jury, admin
  bool _isLoading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await _authService.signUp(
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      role: _role,
    );

    setState(() => _isLoading = false);

    if (error != null) {
      _showErrorDialog(error);
    } else {
      _showSuccessDialog();
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('خطأ في التسجيل'),
            ],
          ),
          content: Text(error),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('موافق'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 8),
              Text('تم التسجيل بنجاح'),
            ],
          ),
          content: const Text(
            'تم إنشاء حسابك بنجاح!\n\n'
            'يرجى التحقق من بريدك الإلكتروني لتفعيل الحساب.\n'
            'بعد ذلك، ستتمكن من تسجيل الدخول.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/login');
              },
              child: const Text('موافق'),
            ),
          ],
        );
      },
    );
  }

  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (value.trim().length < 2) {
      return _errorService.getErrorMessage('VALIDATION_TOO_SHORT');
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (!_isValidEmail(value)) {
      return _errorService.getErrorMessage('AUTH_INVALID_EMAIL');
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (!_isValidPhone(value)) {
      return _errorService.getErrorMessage('AUTH_INVALID_PHONE');
    }
    return null;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^\+?[\d\s\-\(\)]{8,15}$').hasMatch(phone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب جديد'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header avec icône
              Icon(
                Icons.person_add_outlined,
                size: 80,
                color: Colors.deepPurple.shade300,
              ),
              const SizedBox(height: 16),
              const Text(
                'إنشاء حساب جديد',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'املأ البيانات التالية لإنشاء حسابك',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Nom complet
              TextFormField(
                controller: _fullNameController,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: _validateFullName,
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),

              // Téléphone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  hintText: '+966501234567',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 16),

              // Mot de passe avec validation avancée
              PasswordFieldWidget(
                controller: _passwordController,
                labelText: 'كلمة المرور',
                showStrengthIndicator: true,
                showSuggestions: true,
              ),
              const SizedBox(height: 16),

              // Confirmation mot de passe
              ConfirmPasswordFieldWidget(
                controller: _confirmPasswordController,
                passwordController: _passwordController,
                labelText: 'تأكيد كلمة المرور',
              ),
              const SizedBox(height: 16),
              // Sélection du rôle
              DropdownButtonFormField<String>(
                value: _role,
                decoration: InputDecoration(
                  labelText: 'الدور',
                  prefixIcon: const Icon(Icons.work_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: const [
                  DropdownMenuItem(value: 'membre', child: Text('عضو عادي')),
                  DropdownMenuItem(
                    value: 'jury',
                    child: Text('عضو لجنة التحكيم'),
                  ),
                  DropdownMenuItem(value: 'admin', child: Text('مدير')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _role = value);
                  }
                },
              ),
              const SizedBox(height: 32),

              // Bouton d'inscription
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'إنشاء الحساب',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
              const SizedBox(height: 16),

              // Lien vers la connexion
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('لديك حساب بالفعل؟ '),
                  TextButton(
                    onPressed: () {
                      context.go('/login');
                    },
                    child: const Text('تسجيل الدخول'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
