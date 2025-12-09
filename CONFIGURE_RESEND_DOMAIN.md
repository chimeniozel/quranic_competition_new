# إعداد نطاق Resend: reset-pass.quranic.competition

## الخطوة 1: التحقق من النطاق في Resend

1. اذهب إلى [Resend Dashboard > Domains](https://resend.com/domains)
2. ابحث عن النطاق `reset-pass.quranic.competition`
3. تأكد من أن حالة النطاق هي **"Verified"** ✅
   - إذا لم يكن مُتحققاً، اتبع التعليمات في `RESEND_DNS_SETUP.md`

## الخطوة 2: إعداد المتغيرات في Supabase

### 2.1 الوصول إلى Supabase Dashboard

1. اذهب إلى [Supabase Dashboard](https://app.supabase.com)
2. اختر مشروعك
3. اذهب إلى **Edge Functions** > **Settings** > **Secrets**

### 2.2 إضافة/تعديل المتغيرات

أضف أو عدّل المتغيرات التالية:

#### إلزامي:
```
RESEND_API_KEY = re_xxxxxxxxxxxxxxxxxxxxx
```
(احصل على API Key من [Resend Dashboard > API Keys](https://resend.com/api-keys))

#### إلزامي (للاستخدام مع النطاق المُتحقق منه):
```
RESEND_FROM_EMAIL = noreply@reset-pass.quranic.competition
```

أو مع اسم المرسل:
```
RESEND_FROM_EMAIL = مسابقة أهل القرآن <noreply@reset-pass.quranic.competition>
```

### 2.3 خيارات أخرى لعنوان المرسل

يمكنك استخدام أي اسم قبل `@reset-pass.quranic.competition`:
- `noreply@reset-pass.quranic.competition` (موصى به)
- `info@reset-pass.quranic.competition`
- `support@reset-pass.quranic.competition`
- `reset-pass@reset-pass.quranic.competition`

## الخطوة 3: إعادة نشر Edge Function

بعد إضافة المتغيرات، أعد نشر Edge Function:

```bash
# تأكد من أنك في مجلد المشروع
cd /path/to/quranic_competition_new

# نشر Edge Function
supabase functions deploy send-password-reset-otp
```

أو إذا كنت تستخدم Supabase CLI محلياً:
```bash
supabase functions deploy send-password-reset-otp --project-ref YOUR_PROJECT_REF
```

## الخطوة 4: اختبار الإرسال

### 4.1 اختبار من التطبيق

1. افتح التطبيق
2. اذهب إلى صفحة "نسيت كلمة المرور"
3. أدخل عنوان بريد إلكتروني
4. اضغط على "إرسال رمز التحقق"
5. تحقق من وصول البريد الإلكتروني

### 4.2 اختبار من Terminal (اختياري)

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/send-password-reset-otp \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "user_email": "test@example.com",
    "otp_code": "123456"
  }'
```

## التحقق من المشكلة

### إذا لم يصل البريد الإلكتروني:

1. **تحقق من Logs في Supabase:**
   - اذهب إلى Supabase Dashboard > Edge Functions > Logs
   - ابحث عن استدعاءات `send-password-reset-otp`
   - تحقق من رسائل الخطأ

2. **تحقق من Logs في Resend:**
   - اذهب إلى [Resend Dashboard > Logs](https://resend.com/emails)
   - ابحث عن محاولات الإرسال
   - تحقق من حالة الإرسال (Sent, Bounced, etc.)

3. **تحقق من المتغيرات:**
   - تأكد من أن `RESEND_API_KEY` صحيح
   - تأكد من أن `RESEND_FROM_EMAIL` يستخدم النطاق الصحيح
   - تأكد من أن النطاق مُتحقق منه في Resend

4. **تحقق من Spam Folder:**
   - قد يصل البريد إلى مجلد Spam
   - تحقق من جميع مجلدات البريد

## الأخطاء الشائعة

### خطأ: "Domain not verified"
- **السبب:** النطاق غير مُتحقق منه في Resend
- **الحل:** اتبع التعليمات في `RESEND_DNS_SETUP.md` للتحقق من النطاق

### خطأ: "Invalid email format"
- **السبب:** تنسيق `RESEND_FROM_EMAIL` غير صحيح
- **الحل:** استخدم التنسيق: `email@reset-pass.quranic.competition`

### خطأ: "API key invalid"
- **السبب:** `RESEND_API_KEY` غير صحيح أو منتهي الصلاحية
- **الحل:** احصل على API Key جديد من Resend Dashboard

### البريد لا يصل إلى بعض العناوين
- **السبب:** قد يكون هناك قيود على النطاق أو العناوين
- **الحل:** 
  - تحقق من Logs في Resend
  - تأكد من أن النطاق مُتحقق منه بالكامل
  - تحقق من أن DKIM و SPF تم إعدادهما بشكل صحيح

## ملاحظات مهمة

1. **بعد إضافة المتغيرات في Supabase:**
   - يجب إعادة نشر Edge Function لتطبيق التغييرات
   - قد يستغرق نشر DNS من 5 دقائق إلى 24 ساعة

2. **الأمان:**
   - لا تشارك `RESEND_API_KEY` في الكود المصدري
   - استخدم Secrets في Supabase فقط
   - راقب استخدامك في Resend Dashboard

3. **الحدود:**
   - تحقق من حدود خطة Resend الخاصة بك
   - راقب عدد الرسائل المرسلة

## الدعم

إذا استمرت المشكلة:
1. راجع Logs في Supabase و Resend
2. تحقق من [وثائق Resend](https://resend.com/docs)
3. راجع `RESEND_DNS_SETUP.md` للتحقق من إعدادات DNS
4. راجع `RESEND_EMAIL_RESTRICTIONS_FIX.md` لحل مشاكل القيود



