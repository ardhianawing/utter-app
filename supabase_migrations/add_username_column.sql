-- ============================================================
-- Migration: Add username column to profiles table
-- Date: 2026-02-06
-- Description: Add username field to support custom usernames
--              (not just phone numbers) for login
-- ============================================================

-- Step 1: Add username column (nullable initially)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS username TEXT;

-- Step 2: Create index for faster username lookup
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);

-- Step 3: Populate username with phone number as fallback for existing users
UPDATE profiles
SET username = phone
WHERE username IS NULL AND phone IS NOT NULL;

-- Step 4: Add unique constraint (after data migration)
-- Note: Uncomment this after verifying all users have usernames
-- ALTER TABLE profiles
-- ADD CONSTRAINT unique_username UNIQUE (username);

-- Step 5: Add comment
COMMENT ON COLUMN profiles.username IS 'Custom username for login (can be different from phone)';

-- ============================================================
-- Verification Query (run this to check)
-- ============================================================
-- SELECT id, name, phone, username, role FROM profiles ORDER BY created_at;
