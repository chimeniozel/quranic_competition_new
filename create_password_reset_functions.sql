-- دالة RPC لإعادة تعيين كلمة المرور باستخدام Admin API
-- ملاحظة: هذا يتطلب استخدام Service Role Key في Edge Function
-- لأن Supabase Client لا يدعم تغيير كلمة مرور مستخدم آخر مباشرة

-- دالة لإرسال رمز OTP عبر البريد الإلكتروني
CREATE OR REPLACE FUNCTION send_password_reset_otp(user_email TEXT, otp_code TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- هذه الدالة يجب أن تستدعى من Edge Function
  -- لأن Supabase لا يدعم إرسال بريد مخصص مباشرة من RPC
  -- يمكن استخدام Supabase Auth لإرسال البريد مع الرمز في الرسالة
  
  -- في الوقت الحالي، سنستخدم Edge Function لإرسال البريد
  -- هذا مجرد placeholder
  RAISE NOTICE 'OTP code % sent to %', otp_code, user_email;
END;
$$;

-- دالة لإعادة تعيين كلمة المرور
-- ملاحظة: هذه الدالة تحتاج إلى Service Role Key
-- يجب استدعاؤها من Edge Function فقط
CREATE OR REPLACE FUNCTION reset_user_password(user_email TEXT, new_password TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_id UUID;
BEGIN
  -- البحث عن المستخدم بالبريد الإلكتروني
  SELECT id INTO user_id
  FROM auth.users
  WHERE email = user_email;
  
  IF user_id IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  
  -- تحديث كلمة المرور
  -- ملاحظة: هذا يتطلب استخدام Supabase Admin API
  -- يجب استدعاء هذه الدالة من Edge Function مع Service Role Key
  -- لأن Supabase Client لا يدعم تغيير كلمة مرور مستخدم آخر
  
  -- في الوقت الحالي، سنستخدم طريقة بديلة:
  -- استخدام resetPasswordForEmail ثم تسجيل الدخول تلقائياً
  -- أو استخدام Supabase Admin API عبر Edge Function
  
  RAISE NOTICE 'Password reset requested for user %', user_email;
END;
$$;

-- تعليق على الدوال
COMMENT ON FUNCTION send_password_reset_otp IS 'إرسال رمز OTP عبر البريد الإلكتروني (يجب استدعاؤها من Edge Function)';
COMMENT ON FUNCTION reset_user_password IS 'إعادة تعيين كلمة المرور (يجب استدعاؤها من Edge Function مع Service Role Key)';

