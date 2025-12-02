-- جدول لتخزين رموز OTP لإعادة تعيين كلمة المرور
CREATE TABLE IF NOT EXISTS password_reset_otps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  code TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- فهرس للبحث السريع
  CONSTRAINT unique_active_otp UNIQUE (email, code, used)
);

-- إنشاء فهرس للبحث السريع
CREATE INDEX IF NOT EXISTS idx_password_reset_otps_email ON password_reset_otps(email);
CREATE INDEX IF NOT EXISTS idx_password_reset_otps_code ON password_reset_otps(code);
CREATE INDEX IF NOT EXISTS idx_password_reset_otps_expires_at ON password_reset_otps(expires_at);

-- دالة لتنظيف الرموز المنتهية الصلاحية (يمكن تشغيلها بشكل دوري)
CREATE OR REPLACE FUNCTION cleanup_expired_otps()
RETURNS void AS $$
BEGIN
  DELETE FROM password_reset_otps
  WHERE expires_at < NOW() OR used = TRUE;
END;
$$ LANGUAGE plpgsql;

-- تعليق على الجدول
COMMENT ON TABLE password_reset_otps IS 'جدول لتخزين رموز OTP لإعادة تعيين كلمة المرور';
COMMENT ON COLUMN password_reset_otps.email IS 'البريد الإلكتروني للمستخدم';
COMMENT ON COLUMN password_reset_otps.code IS 'رمز OTP (6 أرقام)';
COMMENT ON COLUMN password_reset_otps.expires_at IS 'وقت انتهاء صلاحية الرمز';
COMMENT ON COLUMN password_reset_otps.used IS 'هل تم استخدام الرمز أم لا';

