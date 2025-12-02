# إعداد DNS Records لـ Resend Domain

## Domain: `reset-pass.quranic.competition`

### السجلات المطلوبة (Required)

#### 1. DKIM Record
- **Type**: `TXT`
- **Host/Name**: `resend._domainkey.reset-pass`
- **Value**: 
  ```
  p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDoyjJmdX8Zg6bktOAmoC60WEjoz9kmJoAk4WfLxlBVoyUJWoMBvzj4nQ3f1vJlkgSl8Sx4G62Op22BwvHXplqaNHjWxWimtmAhP6qgbR8ZOvrM9ziBf8b1ScOkCDb9tDyExFD9N8NAVKWIU3iGYoTQ9/maDdOZjC8x5xidShNgoQIDAQAB
  ```
- **Priority**: (فارغ)

#### 2. SPF Records

**Record 1:**
- **Type**: `TXT`
- **Host/Name**: `send.reset-pass`
- **Value**: `feedback-smtp.eu-west-1.amazonses.com`
- **Priority**: `10`

**Record 2:**
- **Type**: `TXT`
- **Host/Name**: `send.reset-pass`
- **Value**: `v=spf1 include:amazonses.com ~all`
- **Priority**: (فارغ)

### السجلات الموصى بها (Recommended)

#### 3. DMARC Record
- **Type**: `TXT`
- **Host/Name**: `_dmarc`
- **Value**: `v=DMARC1; p=none;`

## خطوات الإضافة

### 1. الوصول إلى DNS Provider
اذهب إلى مزود DNS الخاص بك (مثل Cloudflare, Namecheap, GoDaddy, etc.)

### 2. إضافة السجلات
أضف كل سجل من السجلات أعلاه في لوحة تحكم DNS.

### 3. الانتظار
انتظر حتى يتم نشر السجلات (عادة 5-60 دقيقة).

### 4. التحقق
بعد إضافة السجلات، اذهب إلى:
- [Resend Dashboard > Domains](https://resend.com/domains)
- اختر domain `reset-pass.quranic.competition`
- اضغط على "Verify" أو "Complete Verification"

## بعد التحقق

بعد التحقق من Domain، قم بإعداد:

### في Supabase Dashboard > Edge Functions > Settings > Secrets:

```
RESEND_FROM_EMAIL = reset-pass@quranic.competition
```

أو مع اسم:

```
RESEND_FROM_EMAIL = مسابقة أهل القرآن <reset-pass@quranic.competition>
```

## ملاحظات مهمة

1. **التنسيق الصحيح**: استخدم `reset-pass@quranic.competition` (مع @ وليس .)
2. **الانتظار**: قد يستغرق نشر DNS من 5 دقائق إلى 24 ساعة
3. **التحقق**: تأكد من أن جميع السجلات تم إضافتها بشكل صحيح
4. **الأمان**: DKIM و SPF مهمان لمنع spam وتحسين التسليم

## استكشاف الأخطاء

إذا لم يتم التحقق:
1. تحقق من أن السجلات تم إضافتها بشكل صحيح
2. استخدم أداة مثل [MXToolbox](https://mxtoolbox.com/) للتحقق من السجلات
3. تأكد من أن Host/Name صحيح (يجب أن يكون subdomain كامل)
4. انتظر وقتاً كافياً لنشر DNS

