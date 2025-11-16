# دليل حذف المستخدم من Supabase Auth

## المشكلة
حذف المستخدم من `auth.users` لا يعمل بشكل صحيح - المستخدم لا يزال موجوداً في Auth.

## الحلول الممكنة

### الحل 1: استخدام RPC Function (الأسهل)
1. قم بتشغيل ملف `delete_user_from_auth.sql` في Supabase SQL Editor
2. تأكد من أن RPC function تم إنشاؤها بنجاح
3. الكود في `user_management_service.dart` سيستخدمها تلقائياً

**ملاحظة**: قد لا يعمل هذا الحل إذا كان Supabase يمنع الوصول المباشر إلى `auth.users` من RPC functions.

### الحل 2: استخدام Supabase Admin API مع Service Role Key (الأكثر موثوقية)

#### الخطوة 1: إنشاء Edge Function
أنشئ Edge Function في Supabase Dashboard:

```typescript
// supabase/functions/delete-user/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { userId } = await req.json()
    
    // Create admin client with service role key
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Delete user from auth
    const { error } = await supabaseAdmin.auth.admin.deleteUser(userId)
    
    if (error) {
      throw error
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
```

#### الخطوة 2: تحديث الكود في Flutter
استبدل استدعاء RPC function باستدعاء Edge Function:

```dart
// في user_management_service.dart
try {
  final response = await _supabase.functions.invoke(
    'delete-user',
    body: {'userId': userId},
  );
  
  if (response.status == 200) {
    authDeleted = true;
    print('✅ Utilisateur supprimé de Supabase Auth via Edge Function');
  }
} catch (e) {
  print('❌ Erreur lors de la suppression Auth via Edge Function: $e');
}
```

### الحل 3: التأكد من إعدادات Supabase Client
إذا كنت تستخدم service role key في Flutter (غير موصى به لأسباب أمنية)، تأكد من:
1. إضافة service role key في `main.dart` عند تهيئة Supabase
2. استخدام `SupabaseClient` مع service role key فقط على الخادم

## التوصية
استخدم **الحل 2 (Edge Function)** لأنه:
- أكثر أماناً (service role key على الخادم فقط)
- أكثر موثوقية
- يتبع أفضل الممارسات

## التحقق من الحل
بعد تطبيق الحل:
1. احذف مستخدم من التطبيق
2. تحقق في Supabase Dashboard > Authentication > Users
3. يجب ألا يظهر المستخدم المحذوف

