# إضافة أعمدة الصلاحيات إلى جدول profiles

## 📋 الوصف

هذا السكريبت SQL يضيف أعمدة الصلاحيات إلى جدول `profiles` في قاعدة البيانات Supabase. هذه الأعمدة تسمح بإدارة صلاحيات مفصلة لكل مستخدم.

## 🔑 الصلاحيات المتاحة

1. **can_create_versions** - إنشاء نسخ جديدة من المسابقة
2. **can_publish_content** - نشر المحتوى (فوائد قرآنية، إلخ)
3. **can_validate_accounts** - توثيق/إلغاء توثيق حسابات المستخدمين
4. **can_delete** - حذف المحتوى
5. **can_modify** - تعديل المحتوى
6. **can_modify_versions** - تعديل نسخ المسابقة
7. **can_assign_roles** - تعيين أدوار للمستخدمين
8. **can_view_content** - عرض المحتوى (متاح لجميع المستخدمين)

## 🎯 الصلاحيات الافتراضية حسب الدور

### Super Admin (مدير عام)
- ✅ جميع الصلاحيات مفعلة

### Admin (مدير)
- ✅ can_create_versions
- ✅ can_publish_content
- ✅ can_validate_accounts
- ✅ can_view_content
- ❌ can_delete
- ❌ can_modify
- ❌ can_modify_versions
- ❌ can_assign_roles

### Jury (عضو لجنة التحكيم)
- ✅ can_view_content
- ❌ جميع الصلاحيات الأخرى

### Member (عضو عادي)
- ✅ can_view_content
- ❌ جميع الصلاحيات الأخرى

## 📝 خطوات التنفيذ

### 1. فتح Supabase Dashboard
- اذهب إلى [Supabase Dashboard](https://app.supabase.com)
- اختر مشروعك

### 2. فتح SQL Editor
- من القائمة الجانبية، اختر **SQL Editor**
- انقر على **New Query**

### 3. تنفيذ السكريبت
- انسخ محتوى ملف `create_user_permissions_columns.sql`
- الصقه في SQL Editor
- انقر على **Run** أو اضغط `Ctrl+Enter` (Windows/Linux) أو `Cmd+Enter` (Mac)

### 4. التحقق من النتيجة
- يجب أن ترى رسالة نجاح
- يمكنك التحقق من الأعمدة الجديدة باستخدام الاستعلام التالي:

```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
  AND column_name LIKE 'can_%'
ORDER BY column_name;
```

## ⚙️ الميزات

### 1. التهيئة التلقائية
- يتم تهيئة الصلاحيات تلقائياً عند إنشاء مستخدم جديد حسب دوره
- يتم تحديث الصلاحيات عند تغيير دور المستخدم (إذا لم تكن مخصصة)

### 2. التخصيص
- يمكن تخصيص صلاحيات كل مستخدم من صفحة إدارة الأدوار
- الصلاحيات المخصصة لا تتغير عند تغيير الدور

## 🔍 التحقق من الصلاحيات

للتحقق من صلاحيات مستخدم معين:

```sql
SELECT 
  id, 
  full_name, 
  role, 
  can_create_versions, 
  can_publish_content, 
  can_validate_accounts,
  can_delete, 
  can_modify, 
  can_modify_versions, 
  can_assign_roles, 
  can_view_content
FROM profiles
WHERE id = 'USER_ID_HERE';
```

## ⚠️ ملاحظات مهمة

1. **النسخ الاحتياطي**: يُنصح بعمل نسخة احتياطية من قاعدة البيانات قبل تنفيذ السكريبت
2. **الصلاحيات الافتراضية**: يتم تعيين الصلاحيات الافتراضية للمستخدمين الموجودين حسب أدوارهم الحالية
3. **التحديثات المستقبلية**: عند إضافة مستخدمين جدد، سيتم تهيئة صلاحياتهم تلقائياً حسب دورهم

## 🐛 استكشاف الأخطاء

إذا واجهت أي مشاكل:

1. تأكد من أن لديك صلاحيات `ALTER TABLE` على جدول `profiles`
2. تحقق من أن جدول `profiles` موجود
3. تأكد من أن الأعمدة لم تُنشأ مسبقاً (السكريبت يستخدم `IF NOT EXISTS`)

## 📞 الدعم

إذا واجهت أي مشاكل أو لديك أسئلة، يرجى التواصل مع فريق التطوير.

