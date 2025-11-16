# إصلاح Foreign Key Constraint لجدول Evaluations

## المشكلة
عند محاولة إدراج تقييم جديد، يظهر الخطأ التالي:
```
PostgrestException(message: insert or update on table "evaluations" violates foreign key constraint "evaluations_jury_id_fkey", code: 23503, details: Key (jury_id)=(c0e9c56e-b633-437c-8277-ea5dde26bb01) is not present in table "users"., hint: null)
```

## السبب
الـ foreign key constraint `evaluations_jury_id_fkey` يشير إلى جدول `users` غير موجود. يجب أن يشير إلى جدول `profiles` أو `auth.users`.

## الحل

### الخطوة 1: تشغيل SQL Script
1. افتح Supabase Dashboard
2. اذهب إلى SQL Editor
3. انسخ محتوى ملف `fix_evaluations_jury_id_foreign_key.sql`
4. قم بتشغيله

### الخطوة 2: التحقق من الإصلاح
بعد تشغيل SQL script، تحقق من أن الـ constraint تم إصلاحه:
- يجب أن يشير `evaluations_jury_id_fkey` إلى جدول `profiles`
- يجب أن يكون الـ column المحدد هو `id`

### الخطوة 3: اختبار الإصلاح
1. حاول إدراج تقييم جديد من التطبيق
2. يجب أن يعمل بدون أخطاء

## التغييرات في الكود
تم تحسين `evaluation_service.dart` لـ:
- التحقق من وجود المحكم في `profiles` قبل الإدراج
- إظهار رسالة خطأ أوضح عند فشل foreign key constraint
- توجيه المستخدم إلى تشغيل SQL script إذا لزم الأمر

## ملاحظات
- إذا استمرت المشكلة بعد تشغيل SQL script، تأكد من أن:
  - جدول `profiles` موجود
  - جميع المستخدمين موجودون في `profiles`
  - الـ constraint تم إنشاؤه بشكل صحيح

