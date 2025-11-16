-- Fix foreign key constraint for evaluations.jury_id
-- The constraint currently points to a non-existent 'users' table
-- It should point to auth.users or profiles table

-- Step 1: Drop the existing incorrect foreign key constraint
ALTER TABLE evaluations 
DROP CONSTRAINT IF EXISTS evaluations_jury_id_fkey;

-- Step 2: Add the correct foreign key constraint pointing to auth.users
-- Note: In Supabase, we typically reference auth.users via profiles table
-- But since profiles.id references auth.users.id, we can reference profiles instead

-- Option A: Reference profiles table (recommended)
ALTER TABLE evaluations
ADD CONSTRAINT evaluations_jury_id_fkey
FOREIGN KEY (jury_id) 
REFERENCES profiles(id) 
ON DELETE CASCADE;

-- Option B: If you need to reference auth.users directly (requires special permissions)
-- ALTER TABLE evaluations
-- ADD CONSTRAINT evaluations_jury_id_fkey
-- FOREIGN KEY (jury_id) 
-- REFERENCES auth.users(id) 
-- ON DELETE CASCADE;

-- Verify the constraint was created correctly
SELECT 
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    confrelid::regclass AS referenced_table,
    a.attname AS column_name,
    af.attname AS referenced_column
FROM pg_constraint c
JOIN pg_attribute a ON a.attnum = ANY(c.conkey) AND a.attrelid = c.conrelid
JOIN pg_attribute af ON af.attnum = ANY(c.confkey) AND af.attrelid = c.confrelid
WHERE conrelid = 'evaluations'::regclass
AND conname = 'evaluations_jury_id_fkey';

