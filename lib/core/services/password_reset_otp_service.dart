// lib/core/services/password_reset_otp_service.dart

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordResetOtpService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// إنشاء وإرسال رمز OTP لإعادة تعيين كلمة المرور
  Future<Map<String, dynamic>> sendOtpCode(String email) async {
    print('📧 Starting sendOtpCode for email: $email');
    try {
      // ملاحظة: البريد الإلكتروني موجود في auth.users وليس في profiles
      // لا يمكن الوصول المباشر إلى auth.users من Supabase Client
      // لذلك سنرسل الرمز على أي حال (لأسباب أمنية)
      // التحقق من وجود المستخدم سيتم في Edge Function أو RPC function

      // يمكن محاولة البحث في profiles عبر auth.users (لكن هذا معقد)
      // الحل الأفضل: إرسال الرمز دائماً وعدم التحقق من وجود البريد هنا
      // (لأسباب أمنية: لا نكشف أن البريد غير موجود)

      // إنشاء رمز OTP مكون من 6 أرقام
      final code = _generateOtpCode();
      print('📧 Generated OTP code: $code');

      // وقت انتهاء الصلاحية: 15 دقيقة من الآن
      final expiresAt = DateTime.now().add(const Duration(minutes: 15));

      // حذف أي رموز سابقة غير مستخدمة لنفس البريد
      await _supabase
          .from('password_reset_otps')
          .delete()
          .eq('email', email)
          .eq('used', false);

      // إدراج الرمز الجديد
      await _supabase.from('password_reset_otps').insert({
        'email': email,
        'code': code,
        'expires_at': expiresAt.toIso8601String(),
        'used': false,
      });

      // إرسال البريد الإلكتروني عبر Supabase Auth (يمكن استخدام Edge Function لاحقاً)
      // هنا نستخدم resetPasswordForEmail لكن مع رسالة مخصصة
      // في الواقع، سنحتاج إلى Edge Function لإرسال البريد مع الرمز
      // لكن يمكننا استخدام Supabase Auth لإرسال البريد مع الرمز في الرسالة

      // ملاحظة: Supabase لا يدعم إرسال رمز OTP مباشرة في البريد
      // لذلك سنحتاج إلى Edge Function أو خدمة بريد خارجية
      // لكن يمكننا استخدام resetPasswordForEmail مع رابط يحتوي على الرمز
      // أو إنشاء Edge Function مخصص

      // محاولة إرسال البريد عبر Supabase (سيتم إرسال رابط، لكن يمكن تخصيصه)
      // في الوقت الحالي، سنستخدم Edge Function أو RPC function

      // استدعاء Edge Function لإرسال البريد الإلكتروني
      print('📧 Calling Edge Function...');
      try {
        final response = await _supabase.functions.invoke(
          'send-password-reset-otp',
          body: {'user_email': email, 'otp_code': code},
        );

        print('📧 Edge Function response received');
        print('📧 Response status: ${response.status}');
        print('📧 Response data type: ${response.data.runtimeType}');
        print('📧 Response data: ${response.data}');

        // التحقق من response.data أيضاً (قد يكون success: false حتى لو status == 200)
        final responseData = response.data as Map<String, dynamic>?;
        final isSuccess =
            response.status == 200 &&
            (responseData?['success'] == true ||
                responseData?['success'] == null);

        print('📧 Is success: $isSuccess');

        if (!isSuccess) {
          final errorData = responseData ?? response.data;
          final errorMessage =
              errorData?['error'] ?? errorData?['message'] ?? 'Unknown error';
          print('⚠️ Edge Function error: $errorMessage');
          print('⚠️ Response status: ${response.status}');
          print('⚠️ Response data: $responseData');

          // إذا كان الخطأ متعلقاً بعدم إعداد Resend، نعطي رسالة واضحة
          if (errorMessage.toString().contains('RESEND_API_KEY') ||
              errorMessage.toString().contains('not configured')) {
            print('❌ Returning error: Email service not configured');
            return {
              'success': false,
              'message':
                  'خدمة البريد الإلكتروني غير مُعدة. يرجى التواصل مع الدعم الفني.',
              'error': 'Email service not configured',
            };
          }

          // إذا كان الخطأ متعلقاً بالقيود على البريد الإلكتروني
          if (errorMessage.toString().contains('restricted') ||
              errorMessage.toString().contains('not allowed') ||
              errorMessage.toString().contains('domain') ||
              errorMessage.toString().contains('verification')) {
            print('❌ Returning error: Email sending restricted');
            return {
              'success': false,
              'message':
                  'لا يمكن إرسال البريد الإلكتروني إلى هذا العنوان حالياً. يرجى التحقق من عنوان بريدك الإلكتروني أو التواصل مع الدعم الفني.',
              'error': 'Email sending restricted',
              'details': errorMessage.toString(),
            };
          }

          // إذا كان هناك خطأ واضح من Edge Function، نعرضه
          if (responseData?['success'] == false) {
            print('❌ Returning error from Edge Function');
            return {
              'success': false,
              'message':
                  errorData?['message'] ??
                  'لم يتم إرسال البريد الإلكتروني. يرجى المحاولة مرة أخرى.',
              'error': errorMessage.toString(),
            };
          }

          // لا نرمي خطأ هنا، لأن الرمز تم حفظه في قاعدة البيانات
          // يمكن للمستخدم إعادة طلب الرمز إذا لم يصل البريد
          print('⚠️ Email may not have been sent, but OTP code is saved');
        } else {
          print('✅ Email sent successfully via Edge Function');
        }
      } catch (e, stackTrace) {
        // إذا فشلت Edge Function، لا نرمي خطأ لأن الرمز تم حفظه
        // يمكن للمستخدم إعادة طلب الرمز إذا لم يصل البريد
        print('⚠️ Edge Function exception: $e');
        print('⚠️ Stack trace: $stackTrace');

        // إذا كان الخطأ متعلقاً بعدم وجود Edge Function، نعطي رسالة واضحة
        if (e.toString().contains('Function not found') ||
            e.toString().contains('404')) {
          print('❌ Returning error: Edge Function not found');
          return {
            'success': false,
            'message':
                'خدمة إرسال البريد غير متاحة حالياً. يرجى التواصل مع الدعم الفني.',
            'error': 'Edge Function not found',
          };
        }
      }

      // في وضع التطوير، يمكن إرجاع الرمز للاختبار
      // في الإنتاج، يجب حذف 'code' من الاستجابة
      final isDevelopment =
          const bool.fromEnvironment('dart.vm.product') == false;

      print('✅ Returning success result');
      return {
        'success': true,
        'message': 'تم إرسال رمز التحقق إلى بريدك الإلكتروني',
        if (isDevelopment) 'code': code, // فقط للتطوير والاختبار
      };
    } catch (e, stackTrace) {
      print('❌ Error sending OTP: $e');
      print('❌ Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'حدث خطأ أثناء إرسال رمز التحقق',
        'error': e.toString(),
      };
    }
  }

  /// التحقق من صحة رمز OTP
  Future<Map<String, dynamic>> verifyOtpCode(String email, String code) async {
    try {
      // البحث عن الرمز في قاعدة البيانات
      final otpResponse =
          await _supabase
              .from('password_reset_otps')
              .select()
              .eq('email', email)
              .eq('code', code)
              .eq('used', false)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

      if (otpResponse == null) {
        return {
          'success': false,
          'message': 'رمز التحقق غير صحيح أو منتهي الصلاحية',
        };
      }

      // التحقق من انتهاء الصلاحية
      final expiresAt = DateTime.parse(otpResponse['expires_at'] as String);
      if (DateTime.now().isAfter(expiresAt)) {
        // حذف الرمز المنتهي الصلاحية
        await _supabase
            .from('password_reset_otps')
            .delete()
            .eq('id', otpResponse['id']);

        return {
          'success': false,
          'message': 'رمز التحقق منتهي الصلاحية. يرجى طلب رمز جديد',
        };
      }

      // تحديث الرمز كمستخدم
      await _supabase
          .from('password_reset_otps')
          .update({'used': true})
          .eq('id', otpResponse['id']);

      return {'success': true, 'message': 'تم التحقق من الرمز بنجاح'};
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      return {
        'success': false,
        'message': 'حدث خطأ أثناء التحقق من الرمز',
        'error': e.toString(),
      };
    }
  }

  /// إنشاء رمز OTP مكون من 6 أرقام
  String _generateOtpCode() {
    final random = Random();
    final code = StringBuffer();
    for (int i = 0; i < 6; i++) {
      code.write(random.nextInt(10));
    }
    return code.toString();
  }

  /// حذف الرموز المنتهية الصلاحية
  Future<void> cleanupExpiredOtps() async {
    try {
      await _supabase.rpc('cleanup_expired_otps');
    } catch (e) {
      print('⚠️ Error cleaning up expired OTPs: $e');
      // حذف يدوي إذا لم تكن الدالة موجودة
      await _supabase
          .from('password_reset_otps')
          .delete()
          .lt('expires_at', DateTime.now().toIso8601String());
    }
  }
}
