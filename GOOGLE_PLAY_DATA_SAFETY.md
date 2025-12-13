# Google Play Data Safety - معلومات الأمان والبيانات

## البيانات التي يجمعها التطبيق

### 1. المعلومات الشخصية (Personal Information)

#### ✅ البريد الإلكتروني (Email)
- **الغرض**: المصادقة، التواصل مع المستخدمين، إرسال إشعارات
- **مطلوب**: نعم (للتسجيل)
- **مشاركة**: نعم - مع Supabase (مزود قاعدة البيانات)
- **التشفير**: نعم (HTTPS/TLS)
- **الحذف**: يمكن للمستخدم حذف حسابه

#### ✅ رقم الهاتف (Phone Number)
- **الغرض**: المصادقة، التواصل، التحقق من الهوية
- **مطلوب**: نعم (للتسجيل)
- **مشاركة**: نعم - مع Supabase (مزود قاعدة البيانات)
- **التشفير**: نعم (HTTPS/TLS)
- **الحذف**: يمكن للمستخدم حذف حسابه

#### ✅ الاسم الكامل (Full Name)
- **الغرض**: التعريف بالمستخدم، عرض المعلومات في التطبيق
- **مطلوب**: نعم (للتسجيل)
- **مشاركة**: نعم - مع Supabase (مزود قاعدة البيانات)
- **التشفير**: نعم (HTTPS/TLS)
- **الحذف**: يمكن للمستخدم حذف حسابه

#### ✅ معلومات الحساب (Account Information)
- **الغرض**: إدارة الحساب، تحديد الصلاحيات (دور المستخدم)
- **مطلوب**: نعم
- **مشاركة**: نعم - مع Supabase (مزود قاعدة البيانات)
- **التشفير**: نعم (HTTPS/TLS)
- **الحذف**: يمكن للمستخدم حذف حسابه

### 2. الصور والوسائط (Photos & Media)

#### ✅ الصور (Photos)
- **الغرض**: رفع صور المشاركين، المحتوى التعليمي، الوسائط
- **مطلوب**: اختياري (حسب الوظيفة)
- **مشاركة**: نعم - مع Supabase Storage (مزود التخزين)
- **التشفير**: نعم (HTTPS/TLS)
- **الحذف**: يمكن للمستخدم حذف الصور

### 3. معلومات الجهاز (Device Information)

#### ✅ معلومات الجهاز (Device Information)
- **الغرض**: تحسين الأداء، دعم الأجهزة المختلفة
- **مطلوب**: تلقائي
- **مشاركة**: نعم - مع Firebase (للإشعارات)
- **التشفير**: نعم (HTTPS/TLS)

### 4. المعرفات (Identifiers)

#### ✅ معرفات المستخدم (User IDs)
- **الغرض**: المصادقة، ربط البيانات بالمستخدم
- **مطلوب**: نعم
- **مشاركة**: نعم - مع Supabase و Firebase
- **التشفير**: نعم (HTTPS/TLS)

## كيفية استخدام البيانات

### ✅ المصادقة (Authentication)
- استخدام البريد الإلكتروني وكلمة المرور للمصادقة
- استخدام رقم الهاتف للتحقق

### ✅ التواصل (Communication)
- إرسال إشعارات عبر Firebase Cloud Messaging
- التواصل مع المستخدمين حول المسابقة

### ✅ تحسين الخدمة (App Functionality)
- إدارة حسابات المستخدمين
- عرض المحتوى التعليمي
- إدارة المسابقات والتقييمات

### ✅ الأمان (Security)
- حماية البيانات من الوصول غير المصرح به
- تشفير البيانات أثناء النقل والتخزين

## مشاركة البيانات مع أطراف ثالثة

### 1. Supabase (مزود قاعدة البيانات)
- **البيانات المشتركة**: البريد الإلكتروني، رقم الهاتف، الاسم، الصور، معلومات الحساب
- **الغرض**: تخزين البيانات، المصادقة، إدارة قاعدة البيانات
- **السياسة**: [رابط سياسة الخصوصية لـ Supabase](https://supabase.com/privacy)
- **التشفير**: نعم

### 2. Firebase (Google)
- **البيانات المشتركة**: معرفات الأجهزة، معلومات الجهاز
- **الغرض**: إرسال الإشعارات (Firebase Cloud Messaging)
- **السياسة**: [رابط سياسة الخصوصية لـ Firebase](https://firebase.google.com/support/privacy)
- **التشفير**: نعم

## ممارسات الأمان

### ✅ التشفير
- جميع البيانات مشفرة أثناء النقل (HTTPS/TLS)
- كلمات المرور مشفرة باستخدام تقنيات آمنة

### ✅ الوصول إلى البيانات
- الوصول مقيد للمستخدمين المصرح لهم فقط
- استخدام المصادقة والتفويض

### ✅ حذف البيانات
- يمكن للمستخدمين حذف حساباتهم
- يتم حذف البيانات عند طلب المستخدم

## الإذنات المطلوبة

### 1. READ_MEDIA_IMAGES / READ_EXTERNAL_STORAGE
- **الغرض**: اختيار الصور من الجهاز لرفعها في التطبيق
- **الاستخدام**: رفع صور المشاركين، المحتوى التعليمي

### 2. POST_NOTIFICATIONS
- **الغرض**: إرسال إشعارات للمستخدمين حول المسابقة والأحداث
- **الاستخدام**: إشعارات المسابقة، التقييمات، النتائج

### 3. SCHEDULE_EXACT_ALARM
- **الغرض**: جدولة الإشعارات في أوقات محددة
- **الاستخدام**: إشعارات مجدولة للمسابقة

## كيفية ملء قسم Data Safety في Google Play Console

### الخطوات:

1. **اذهب إلى Google Play Console**
2. **اختر التطبيق**
3. **اذهب إلى "Policy" → "Data safety"**
4. **املأ المعلومات التالية:**

#### Data Collection:
- ✅ **Email address** - Required, Encrypted, Shared with third parties (Supabase)
- ✅ **Phone number** - Required, Encrypted, Shared with third parties (Supabase)
- ✅ **Name** - Required, Encrypted, Shared with third parties (Supabase)
- ✅ **Photos and videos** - Optional, Encrypted, Shared with third parties (Supabase Storage)
- ✅ **Device or other IDs** - Automatic, Encrypted, Shared with third parties (Firebase)

#### Data Usage:
- ✅ **App functionality** - Yes
- ✅ **Authentication** - Yes
- ✅ **Analytics** - No (لا نستخدم Analytics)
- ✅ **Developer communications** - Yes (للإشعارات)
- ✅ **Advertising or marketing** - No
- ✅ **Personalization** - No
- ✅ **Account management** - Yes

#### Data Sharing:
- ✅ **Supabase** - Yes (Database and Storage provider)
- ✅ **Firebase (Google)** - Yes (Push notifications)

#### Security Practices:
- ✅ **Data is encrypted in transit** - Yes
- ✅ **Users can request that data be deleted** - Yes

#### Data Collection Purpose:
- ✅ **Authentication** - Email, Phone
- ✅ **Communication** - Email, Phone (for notifications)
- ✅ **App functionality** - All data types
- ✅ **Account management** - All personal information

## ملاحظات مهمة

1. **Privacy Policy**: تأكد من وجود رابط لسياسة الخصوصية في Google Play Console
2. **Data Deletion**: وضح كيفية حذف البيانات في سياسة الخصوصية
3. **User Rights**: وضح حقوق المستخدمين في الوصول إلى بياناتهم وحذفها
4. **Third-party Links**: أضف روابط سياسات الخصوصية لـ Supabase و Firebase

## رابط سياسة الخصوصية المطلوب

يجب أن يكون لديك رابط لسياسة الخصوصية يحتوي على:
- أنواع البيانات المجمعة
- كيفية استخدام البيانات
- مشاركة البيانات مع أطراف ثالثة
- حقوق المستخدمين
- كيفية الاتصال بك

---

**ملاحظة**: تأكد من تحديث هذه المعلومات في Google Play Console قبل نشر التطبيق.

