// Supabase Edge Function لإرسال رمز OTP لإعادة تعيين كلمة المرور
// تستخدم Resend لإرسال البريد الإلكتروني

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// دالة لإرسال البريد الإلكتروني عبر Resend
async function sendEmailViaResend(
  to: string,
  subject: string,
  html: string,
  text?: string
): Promise<{ success: boolean; error?: string }> {
  const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
  // استخدام onboarding@resend.dev (domain افتراضي من Resend - لا يحتاج إلى تحقق)
  // يمكن استخدامه للاختبار والإنتاج
  const RESEND_FROM_EMAIL = Deno.env.get('RESEND_FROM_EMAIL') || 'onboarding@resend.dev';

  if (!RESEND_API_KEY) {
    console.error('❌ RESEND_API_KEY not configured');
    return { 
      success: false, 
      error: 'RESEND_API_KEY not configured. Please set RESEND_API_KEY in Supabase Dashboard > Edge Functions > Settings' 
    };
  }
  
  // التحقق من صحة تنسيق البريد الإلكتروني
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(RESEND_FROM_EMAIL)) {
    console.error(`❌ Invalid email format: ${RESEND_FROM_EMAIL}`);
    return {
      success: false,
      error: `Invalid email format: ${RESEND_FROM_EMAIL}. Must be in format: email@domain.com (use @ not .)`,
    };
  }
  
  console.log(`📧 Using from email: ${RESEND_FROM_EMAIL}`);

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: RESEND_FROM_EMAIL,
        to: [to],
        subject: subject,
        html: html,
        text: text || html.replace(/<[^>]*>/g, ''), // إزالة HTML tags للنص العادي
      }),
    });

    const result = await response.json();

    if (response.ok) {
      console.log(`✅ Email sent successfully to ${to} via Resend`);
      return { success: true };
    } else {
      console.error(`❌ Error sending email via Resend:`, result);
      return { 
        success: false, 
        error: result.message || 'Failed to send email via Resend' 
      };
    }
  } catch (error) {
    console.error(`❌ Exception sending email via Resend:`, error);
    return { 
      success: false, 
      error: error.message || 'Failed to send email' 
    };
  }
}

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
      console.log('📧 Body reçu:', body);
    } catch (e) {
      console.error('❌ Erreur lors de la lecture du body:', e);
      const textBody = await req.text();
      console.log('📧 Body texte:', textBody);
      try {
        body = JSON.parse(textBody);
      } catch (parseError) {
        console.error('❌ Erreur lors du parsing JSON:', parseError);
        throw new Error('Invalid JSON body');
      }
    }

    const { user_email, otp_code } = body;

    if (!user_email || !otp_code) {
      console.error('❌ Missing required parameters:', { user_email, otp_code });
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'Missing required parameters: user_email and otp_code are required' 
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
          error: 'Invalid email format' 
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // التحقق من صحة رمز OTP (يجب أن يكون 6 أرقام)
    if (!/^\d{6}$/.test(otp_code)) {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'Invalid OTP code format. Must be 6 digits' 
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log(`📧 Sending OTP code ${otp_code} to ${user_email}`);

    // التحقق من وجود المستخدم في auth.users (اختياري - لأسباب أمنية)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    try {
      // محاولة البحث عن المستخدم في auth.users
      const { data: users, error: listError } = await supabaseClient.auth.admin.listUsers();
      
      if (!listError && users) {
        const userExists = users.users.some(u => u.email === user_email);
        if (!userExists) {
          // لا نكشف أن البريد غير موجود لأسباب أمنية
          // لكن نرجع نجاح حتى لا يكشف المهاجم عن البريد الإلكتروني
          console.log(`⚠️ User with email ${user_email} not found, but continuing anyway for security`);
        }
      }
    } catch (e) {
      console.warn('⚠️ Could not verify user existence:', e);
      // نستمر على أي حال
    }

    // إنشاء محتوى البريد الإلكتروني
    const emailSubject = 'رمز إعادة تعيين كلمة المرور - مسابقة أهل القرآن الواتسابية';
    const emailHtml = `
      <!DOCTYPE html>
      <html dir="rtl" lang="ar">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            direction: rtl;
            text-align: right;
            background-color: #f5f5f5;
            margin: 0;
            padding: 0;
          }
          .container {
            max-width: 600px;
            margin: 0 auto;
            background-color: #ffffff;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
          .header {
            text-align: center;
            margin-bottom: 30px;
          }
          .header h1 {
            color: #6B46C1;
            font-size: 24px;
            margin: 0;
          }
          .otp-code {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            font-size: 36px;
            font-weight: bold;
            text-align: center;
            padding: 20px;
            border-radius: 8px;
            letter-spacing: 8px;
            margin: 30px 0;
            font-family: 'Courier New', monospace;
          }
          .info {
            background-color: #f0f0f0;
            padding: 15px;
            border-radius: 8px;
            margin: 20px 0;
            border-right: 4px solid #6B46C1;
          }
          .info p {
            margin: 5px 0;
            color: #333;
          }
          .warning {
            background-color: #fff3cd;
            padding: 15px;
            border-radius: 8px;
            margin: 20px 0;
            border-right: 4px solid #ffc107;
          }
          .warning p {
            margin: 5px 0;
            color: #856404;
          }
          .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #e0e0e0;
            color: #666;
            font-size: 12px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🔐 إعادة تعيين كلمة المرور</h1>
          </div>
          
          <p>مرحباً،</p>
          
          <p>لقد طلبت إعادة تعيين كلمة المرور لحسابك في <strong>مسابقة أهل القرآن الواتسابية</strong>.</p>
          
          <p>رمز التحقق الخاص بك هو:</p>
          
          <div class="otp-code">${otp_code}</div>
          
          <div class="info">
            <p><strong>⏱️ صلاحية الرمز:</strong> 15 دقيقة</p>
            <p><strong>📱 الاستخدام:</strong> أدخل هذا الرمز في صفحة التحقق من الرمز</p>
          </div>
          
          <div class="warning">
            <p><strong>⚠️ تحذير أمني:</strong></p>
            <p>إذا لم تطلب إعادة تعيين كلمة المرور، يرجى تجاهل هذا البريد الإلكتروني.</p>
            <p>لا تشارك هذا الرمز مع أي شخص آخر.</p>
          </div>
          
          <div class="footer">
            <p>هذا بريد إلكتروني تلقائي، يرجى عدم الرد عليه.</p>
            <p>© ${new Date().getFullYear()} مسابقة أهل القرآن الواتسابية</p>
          </div>
        </div>
      </body>
      </html>
    `;

    const emailText = `
رمز إعادة تعيين كلمة المرور - مسابقة أهل القرآن الواتسابية

مرحباً،

لقد طلبت إعادة تعيين كلمة المرور لحسابك.

رمز التحقق الخاص بك هو: ${otp_code}

صلاحية الرمز: 15 دقيقة

إذا لم تطلب إعادة تعيين كلمة المرور، يرجى تجاهل هذا البريد الإلكتروني.

هذا بريد إلكتروني تلقائي، يرجى عدم الرد عليه.
    `.trim();

    // إرسال البريد عبر Resend فقط
    const emailResult = await sendEmailViaResend(user_email, emailSubject, emailHtml, emailText);

    if (!emailResult.success) {
      console.error('❌ Failed to send email:', emailResult.error);
      return new Response(
        JSON.stringify({
          success: false,
          error: emailResult.error || 'Failed to send email',
          message: 'لم يتم إرسال البريد الإلكتروني. يرجى التحقق من إعدادات البريد الإلكتروني.',
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log(`✅ OTP code sent successfully to ${user_email}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: 'تم إرسال رمز التحقق بنجاح',
        email: user_email,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  } catch (error) {
    console.error('❌ Error in send-password-reset-otp function:', error);
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
