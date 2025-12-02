# إعداد Edge Function لإرسال رمز OTP

## المتطلبات

### 1. متغيرات البيئة المطلوبة

في Supabase Dashboard > Edge Functions > Settings، أضف المتغيرات التالية:

#### إلزامي:
- `SUPABASE_URL`: رابط Supabase الخاص بك
- `SUPABASE_SERVICE_ROLE_KEY`: Service Role Key (مهم جداً!)

#### إلزامي (لإرسال البريد عبر Resend):
- `RESEND_API_KEY`: API Key من Resend (للحصول عليه: https://resend.com/api-keys)

#### اختياري:
- `RESEND_FROM_EMAIL`: عنوان البريد الإلكتروني المرسل
  - **الافتراضي**: `onboarding@resend.dev` (يعمل للاختبار والإنتاج - لا يحتاج إلى تحقق)
  - **ملاحظة**: يمكن استخدام `onboarding@resend.dev` بدون أي إعدادات إضافية

## خطوات النشر

### 1. نشر Edge Function

```bash
# الانتقال إلى مجلد المشروع
cd /path/to/quranic_competition_new

# نشر Edge Function لإرسال OTP
supabase functions deploy send-password-reset-otp

# نشر Edge Function لإعادة تعيين كلمة المرور
supabase functions deploy reset-password
```

### 2. إعداد Resend (اختياري لكن موصى به)

1. إنشاء حساب على [Resend](https://resend.com)
2. الحصول على API Key من Dashboard
3. إضافة Domain (اختياري) أو استخدام `onboarding@resend.dev` للاختبار
4. إضافة `RESEND_API_KEY` و `RESEND_FROM_EMAIL` في Supabase Dashboard

### 3. اختبار Edge Function

```bash
# اختبار إرسال OTP
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/send-password-reset-otp \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "user_email": "test@example.com",
    "otp_code": "123456"
  }'
```

## كيفية العمل

### 1. إرسال رمز OTP

عند استدعاء Edge Function:
- يتم التحقق من صحة البريد الإلكتروني ورمز OTP
- يتم إنشاء محتوى بريد إلكتروني HTML جميل
- يتم محاولة إرسال البريد عبر Resend أولاً
- إذا فشل Resend، يتم محاولة Supabase Email (لكن محدود)

### 2. محتوى البريد الإلكتروني

البريد الإلكتروني يحتوي على:
- عنوان جميل مع تصميم RTL
- رمز OTP كبير وواضح
- معلومات عن صلاحية الرمز (15 دقيقة)
- تحذيرات أمنية
- تصميم responsive

### 3. معالجة الأخطاء

- إذا فشل إرسال البريد، يتم إرجاع رسالة خطأ واضحة
- يتم تسجيل جميع الأخطاء في console
- الرمز يبقى محفوظاً في قاعدة البيانات حتى لو فشل إرسال البريد

## الأمان

- ✅ التحقق من صحة البريد الإلكتروني
- ✅ التحقق من صحة رمز OTP (6 أرقام فقط)
- ✅ استخدام Service Role Key بشكل آمن
- ✅ عدم إرجاع معلومات حساسة في الاستجابة
- ✅ معالجة آمنة للأخطاء

## ملاحظات مهمة

1. **Service Role Key**: 
   - لا تشارك Service Role Key في الكود المصدري
   - استخدم فقط في Edge Functions
   - لا تستخدمه في Flutter app

2. **Resend API Key**:
   - احفظه في Supabase Secrets
   - لا تشاركه في الكود المصدري
   - استخدم domain خاص بك في الإنتاج

3. **التطوير مقابل الإنتاج**:
   - في التطوير، يمكن إرجاع الرمز في الاستجابة للاختبار
   - في الإنتاج، يجب حذف الرمز من الاستجابة

4. **معدل الإرسال**:
   - Resend لديه حدود على عدد الرسائل
   - راقب استخدامك في Resend Dashboard
   - فكر في استخدام SendGrid أو خدمة أخرى للاستخدام الكبير

## استكشاف الأخطاء

### البريد لا يصل
1. تحقق من `RESEND_API_KEY` في Supabase Dashboard
2. تحقق من `RESEND_FROM_EMAIL` (يجب أن يكون domain مُتحقق منه)
3. تحقق من logs في Supabase Dashboard > Edge Functions > Logs
4. تحقق من spam folder

### خطأ في Edge Function
1. تحقق من logs في Supabase Dashboard
2. تحقق من صحة المتغيرات البيئية
3. تحقق من صحة JSON body المرسل

### الرمز لا يعمل
1. تحقق من أن الرمز لم ينتهِ صلاحيته (15 دقيقة)
2. تحقق من أن الرمز لم يُستخدم من قبل
3. تحقق من أن البريد الإلكتروني صحيح

## الدعم

إذا واجهت مشاكل:
1. راجع logs في Supabase Dashboard
2. راجع [وثائق Resend](https://resend.com/docs)
3. راجع [وثائق Supabase Edge Functions](https://supabase.com/docs/guides/functions)

