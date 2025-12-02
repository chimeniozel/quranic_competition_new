# بنية Edge Functions - لماذا Edge Functions منفصلة؟

## البنية الحالية

لديك حالياً Edge Functions منفصلة:

1. **`send-fcm-notification`**: لإرسال إشعارات Push عبر FCM
2. **`send-password-reset-otp`**: لإرسال رموز OTP عبر البريد الإلكتروني
3. **`reset-password`**: لإعادة تعيين كلمة المرور

## لماذا Edge Functions منفصلة؟

### ✅ المزايا

#### 1. **فصل الاهتمامات (Separation of Concerns)**
- كل Edge Function لها غرض واحد وواضح
- أسهل في الفهم والصيانة
- يمكن تطويرها بشكل مستقل

#### 2. **المتطلبات المختلفة**
- **FCM**: يحتاج `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY`, `FCM_PROJECT_ID`
- **Email**: يحتاج `RESEND_API_KEY`, `RESEND_FROM_EMAIL`
- **Password Reset**: يحتاج `SUPABASE_SERVICE_ROLE_KEY`

#### 3. **سهولة الصيانة**
- إذا حدث خطأ في إرسال البريد، لا يؤثر على إرسال الإشعارات
- أسهل في التصحيح (debugging)
- يمكن تحديث كل واحدة بشكل مستقل

#### 4. **الاستقلالية**
- يمكن نشرها بشكل منفصل
- يمكن إيقاف إحداهما دون التأثير على الأخرى
- يمكن قياس الأداء بشكل منفصل

#### 5. **الأمان**
- كل Edge Function لها permissions مختلفة
- يمكن تقييد الوصول بشكل منفصل
- أسهل في إدارة الأخطاء الأمنية

### ❌ البديل: Edge Function واحدة

يمكن إنشاء Edge Function واحدة مع routes:

```typescript
// مثال (غير موصى به)
serve(async (req) => {
  const { type } = await req.json();
  
  if (type === 'fcm') {
    // إرسال إشعار FCM
  } else if (type === 'email') {
    // إرسال بريد إلكتروني
  }
});
```

**المشاكل:**
- ❌ معقدة أكثر
- ❌ صعبة الصيانة
- ❌ إذا فشلت إحدى الوظائف، قد تؤثر على الأخرى
- ❌ صعبة في التصحيح
- ❌ تحتاج جميع المتغيرات البيئية في مكان واحد

## البنية الموصى بها

```
supabase_edge_function_send_fcm_notification/
  └── index.ts          # إرسال إشعارات FCM

supabase_edge_function_send_password_reset_otp/
  └── index.ts          # إرسال رموز OTP عبر البريد

supabase_edge_function_reset_password/
  └── index.ts          # إعادة تعيين كلمة المرور
```

## متى يمكن دمج Edge Functions؟

يمكن دمج Edge Functions فقط إذا:
- ✅ لها نفس المتطلبات (نفس API keys)
- ✅ لها نفس معدل الاستخدام
- ✅ مرتبطة ببعضها بشكل وثيق
- ✅ بسيطة جداً

**مثال جيد للدمج:**
- إرسال بريد إلكتروني + SMS (نفس الخدمة)
- إرسال إشعارات متعددة من نفس النوع

**مثال سيء للدمج:**
- إرسال إشعارات FCM + إرسال بريد إلكتروني (خدمات مختلفة)
- إعادة تعيين كلمة المرور + إرسال إشعارات (أغراض مختلفة)

## الخلاصة

✅ **نعم، يجب إنشاء Edge Function منفصلة للبريد الإلكتروني**

البنية الحالية صحيحة ومثالية:
- `send-fcm-notification` → للإشعارات
- `send-password-reset-otp` → للبريد الإلكتروني
- `reset-password` → لإعادة تعيين كلمة المرور

هذا يتبع مبدأ **Single Responsibility Principle** ويجعل الكود أسهل في الصيانة والتطوير.

