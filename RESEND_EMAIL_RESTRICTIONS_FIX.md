# حل مشكلة إرسال OTP إلى بعض البريد الإلكتروني فقط

## المشكلة

عند استخدام Resend مع البريد الافتراضي `onboarding@resend.dev`، قد تواجه مشكلة حيث يتم إرسال البريد الإلكتروني إلى بعض العناوين فقط وليس جميعها.

## السبب

Resend يفرض قيوداً على البريد الافتراضي `onboarding@resend.dev` لأسباب أمنية:
- يسمح بإرسال البريد إلى عدد محدود من العناوين
- قد يقتصر على العناوين التي تم التحقق منها مسبقاً
- قد يرفض بعض نطاقات البريد الإلكتروني

## الحلول

### الحل 1: استخدام نطاق مُتحقق منه (موصى به للإنتاج)

1. **إضافة نطاق في Resend:**
   - اذهب إلى [Resend Dashboard > Domains](https://resend.com/domains)
   - اضغط على "Add Domain"
   - أدخل نطاقك (مثل: `quranic.competition`)
   - اتبع التعليمات لإضافة سجلات DNS

2. **إعداد المتغيرات في Supabase:**
   - اذهب إلى Supabase Dashboard > Edge Functions > Settings > Secrets
   - أضف أو عدّل:
     ```
     RESEND_FROM_EMAIL = reset-pass@quranic.competition
     ```
   - أو مع اسم:
     ```
     RESEND_FROM_EMAIL = مسابقة أهل القرآن <reset-pass@quranic.competition>
     ```

3. **إعادة نشر Edge Function:**
   ```bash
   supabase functions deploy send-password-reset-otp
   ```

### الحل 2: التحقق من إعدادات Resend

1. **التحقق من القيود:**
   - اذهب إلى [Resend Dashboard > Settings](https://resend.com/settings)
   - تحقق من "Email Restrictions" أو "Allowed Emails"
   - تأكد من عدم وجود قيود على العناوين

2. **التحقق من API Key:**
   - تأكد من أن API Key لديه الصلاحيات الكافية
   - تحقق من "Rate Limits" في Dashboard

### الحل 3: إضافة عناوين بريد إلكتروني مسموح بها

إذا كنت تستخدم حساب Resend مجاني أو محدود:
- قد تحتاج إلى إضافة العناوين في قائمة المسموح بها
- اذهب إلى Resend Dashboard > Settings > Email Restrictions
- أضف العناوين المسموح بها

### الحل 4: التحقق من Logs

1. **في Supabase:**
   - اذهب إلى Supabase Dashboard > Edge Functions > Logs
   - ابحث عن أخطاء متعلقة بـ Resend
   - تحقق من رسائل الخطأ التفصيلية

2. **في Resend:**
   - اذهب إلى Resend Dashboard > Logs
   - تحقق من محاولات الإرسال الفاشلة
   - ابحث عن رسائل الخطأ مثل:
     - "Email not allowed"
     - "Domain not verified"
     - "Rate limit exceeded"

## التحقق من المشكلة

بعد التعديلات، اختبر إرسال OTP إلى عناوين بريد مختلفة:

1. **عنوان بريد يعمل:**
   - تأكد من أن البريد يصل بنجاح

2. **عنوان بريد لا يعمل:**
   - تحقق من Logs في Supabase و Resend
   - ابحث عن رسائل الخطأ المحددة
   - تأكد من أن الخطأ ليس بسبب spam folder

## رسائل الخطأ الشائعة

### "Email sending restricted"
- **السبب:** Resend يرفض إرسال البريد إلى هذا العنوان
- **الحل:** استخدم نطاق مُتحقق منه أو أضف العنوان إلى القائمة المسموح بها

### "Domain not verified"
- **السبب:** النطاق المستخدم غير مُتحقق منه
- **الحل:** تحقق من النطاق في Resend Dashboard أو استخدم `onboarding@resend.dev`

### "Rate limit exceeded"
- **السبب:** تجاوزت الحد المسموح به من الرسائل
- **الحل:** انتظر أو ترقية حساب Resend

## ملاحظات مهمة

1. **النطاق الافتراضي `onboarding@resend.dev`:**
   - مناسب للاختبار فقط
   - قد يكون له قيود على عدد العناوين
   - قد يرفض بعض نطاقات البريد الإلكتروني

2. **النطاق المُتحقق منه:**
   - أفضل للإنتاج
   - لا توجد قيود على العناوين (ضمن حدود الخطة)
   - يحسن من معدل التسليم

3. **الأمان:**
   - لا تشارك API Keys في الكود المصدري
   - استخدم Secrets في Supabase
   - راقب استخدامك في Resend Dashboard

## الدعم

إذا استمرت المشكلة:
1. راجع Logs في Supabase و Resend
2. تحقق من [وثائق Resend](https://resend.com/docs)
3. تواصل مع دعم Resend إذا لزم الأمر

