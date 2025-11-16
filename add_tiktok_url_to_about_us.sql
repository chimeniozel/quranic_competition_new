-- Add tiktok_url column to about_us table
-- This script adds a new column for TikTok URL in the about_us table

ALTER TABLE about_us
ADD COLUMN IF NOT EXISTS tiktok_url TEXT;

-- Add a comment to the column
COMMENT ON COLUMN about_us.tiktok_url IS 'URL du compte TikTok (ex: https://www.tiktok.com/@username)';

