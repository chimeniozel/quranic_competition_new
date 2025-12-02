// Supabase Edge Function لإعادة تعيين كلمة المرور
// تستخدم Admin API لتغيير كلمة مرور المستخدم

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // قراءة body الطلب
    let body;
    try {
      body = await req.json();
      console.log('🔐 Body reçu:', body);
    } catch (e) {
      console.error('❌ Erreur lors de la lecture du body:', e);
      const textBody = await req.text();
      console.log('🔐 Body texte:', textBody);
      try {
        body = JSON.parse(textBody);
      } catch (parseError) {
        console.error('❌ Erreur lors du parsing JSON:', parseError);
        throw new Error('Invalid JSON body');
      }
    }

    const { user_email, new_password } = body;

    if (!user_email || !new_password) {
      console.error('❌ Missing required parameters:', { user_email, new_password });
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required parameters: user_email and new_password are required',
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // التحقق من صحة البريد الإلكتروني
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(user_email)) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Invalid email format',
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // التحقق من قوة كلمة المرور (اختياري - يمكن إزالته إذا كان التحقق يتم في التطبيق)
    if (new_password.length < 8) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Password must be at least 8 characters long',
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log(`🔐 Resetting password for user: ${user_email}`);

    // إنشاء Supabase Admin client باستخدام Service Role Key
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // البحث عن المستخدم بالبريد الإلكتروني في auth.users
    const { data: users, error: listError } = await supabaseAdmin.auth.admin.listUsers();

    if (listError) {
      console.error('❌ Error listing users:', listError);
      throw listError;
    }

    const user = users.users.find((u) => u.email === user_email);

    if (!user) {
      console.error(`❌ User not found: ${user_email}`);
      return new Response(
        JSON.stringify({
          success: false,
          error: 'User not found',
          message: 'المستخدم غير موجود',
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log(`✅ User found: ${user.id}`);

    // تحديث كلمة المرور باستخدام Admin API
    const { data, error } = await supabaseAdmin.auth.admin.updateUserById(user.id, {
      password: new_password,
    });

    if (error) {
      console.error('❌ Error updating password:', error);
      throw error;
    }

    console.log(`✅ Password reset successfully for user: ${user_email}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: 'تم إعادة تعيين كلمة المرور بنجاح',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  } catch (error) {
    console.error('❌ Error in reset-password function:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Internal server error',
        details: error.stack,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

