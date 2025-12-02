# نظام إعادة تعيين كلمة المرور باستخدام رمز OTP

تم تحديث نظام إعادة تعيين كلمة المرور لاستخدام رمز OTP (One-Time Password) بدلاً من الرابط.

## الملفات المضافة/المحدثة

### 1. قاعدة البيانات
- **`create_password_reset_otp_table.sql`**: جدول لتخزين رموز OTP
- **`create_password_reset_functions.sql`**: دوال RPC لإعادة تعيين كلمة المرور

### 2. الخدمات
- **`lib/core/services/password_reset_otp_service.dart`**: خدمة لإدارة رموز OTP

### 3. الصفحات
- **`lib/features/auth/pages/forgot_password_page.dart`**: تحديث لإرسال رمز OTP بدلاً من رابط
- **`lib/features/auth/pages/verify_otp_page.dart`**: صفحة جديدة للتحقق من رمز OTP
- **`lib/features/auth/pages/reset_password_page.dart`**: تحديث للعمل مع البريد الإلكتروني

### 4. Edge Functions
- **`supabase_edge_function_send_password_reset_otp/index.ts`**: Edge Function لإرسال رمز OTP عبر البريد
- **`supabase_edge_function_reset_password/index.ts`**: Edge Function لإعادة تعيين كلمة المرور

### 5. Routing
- **`lib/app/router.dart`**: إضافة route لصفحة التحقق من الرمز

## خطوات التنفيذ

### 1. إنشاء الجدول والدوال في Supabase

قم بتشغيل الملفات التالية في Supabase SQL Editor:

```sql
-- إنشاء جدول OTP
\i create_password_reset_otp_table.sql

-- إنشاء الدوال
\i create_password_reset_functions.sql
```

### 2. نشر Edge Functions

#### إرسال رمز OTP:
```bash
supabase functions deploy send-password-reset-otp
```

#### إعادة تعيين كلمة المرور:
```bash
supabase functions deploy reset-password
```

### 3. إعداد متغيرات البيئة

في Supabase Dashboard > Edge Functions > Settings، أضف:

- `SUPABASE_URL`: رابط Supabase الخاص بك
- `SUPABASE_SERVICE_ROLE_KEY`: Service Role Key (مهم جداً!)
- `RESEND_API_KEY` (اختياري): إذا كنت تستخدم Resend لإرسال البريد

### 4. تخصيص قالب البريد الإلكتروني

في Supabase Dashboard > Authentication > Email Templates، يمكنك تخصيص قالب البريد الإلكتروني لإرسال رمز OTP.

## كيفية العمل

1. **طلب إعادة تعيين كلمة المرور**:
   - المستخدم يدخل بريده الإلكتروني في `forgot_password_page.dart`
   - يتم إنشاء رمز OTP مكون من 6 أرقام وحفظه في قاعدة البيانات
   - يتم إرسال الرمز إلى البريد الإلكتروني عبر Edge Function

2. **التحقق من الرمز**:
   - المستخدم يدخل الرمز في `verify_otp_page.dart`
   - يتم التحقق من صحة الرمز وانتهاء صلاحيته
   - إذا كان صحيحاً، يتم الانتقال إلى صفحة إعادة تعيين كلمة المرور

3. **إعادة تعيين كلمة المرور**:
   - المستخدم يدخل كلمة المرور الجديدة في `reset_password_page.dart`
   - يتم تحديث كلمة المرور عبر Edge Function باستخدام Admin API
   - يتم تسجيل خروج المستخدم تلقائياً

## الأمان

- الرموز صالحة لمدة 15 دقيقة فقط
- الرموز تُحذف تلقائياً بعد الاستخدام
- الرموز المنتهية الصلاحية تُحذف تلقائياً
- لا يمكن استخدام نفس الرمز مرتين

## ملاحظات مهمة

1. **إرسال البريد الإلكتروني**: 
   - Supabase لا يدعم إرسال بريد مخصص مباشرة
   - يجب استخدام Edge Function مع خدمة بريد خارجية (مثل Resend أو SendGrid)
   - أو استخدام Supabase Email Templates مع متغيرات مخصصة

2. **إعادة تعيين كلمة المرور**:
   - Supabase Client لا يدعم تغيير كلمة مرور مستخدم آخر
   - يجب استخدام Admin API عبر Edge Function مع Service Role Key
   - **مهم جداً**: لا تشارك Service Role Key في الكود المصدري!

3. **التطوير والاختبار**:
   - في وضع التطوير، يتم إرجاع الرمز في الاستجابة (يجب حذفه في الإنتاج)
   - يمكن استخدام Supabase Local Development للاختبار

## التحسينات المستقبلية

- [ ] إضافة إعادة إرسال الرمز مع عداد زمني
- [ ] إضافة محاولات محدودة للتحقق من الرمز
- [ ] إضافة تسجيل محاولات إعادة التعيين
- [ ] تحسين تصميم صفحات OTP
- [ ] إضافة دعم SMS لإرسال الرمز

