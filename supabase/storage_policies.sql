-- Supabase Storage Policies for MIWODO
-- Run this in the Supabase SQL Editor (Dashboard > SQL > New Query)
-- IMPORTANT: The Flutter app uses Firebase Auth, NOT Supabase Auth.
-- So uploads are made with the anon key, not an authenticated Supabase session.
-- This means we need to allow anon (public) uploads, not just authenticated.

-- 1. Create the bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('miwodo-photos', 'miwodo-photos', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Set bucket to public (so getPublicUrl works for reads)
UPDATE storage.buckets
SET public = true
WHERE id = 'miwodo-photos';

-- 3. Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Public read access for miwodo-photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload to miwodo-photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated update to miwodo-photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated delete from miwodo-photos" ON storage.objects;
DROP POLICY IF EXISTS "Public upload to miwodo-photos" ON storage.objects;
DROP POLICY IF EXISTS "Public update to miwodo-photos" ON storage.objects;
DROP POLICY IF EXISTS "Public delete from miwodo-photos" ON storage.objects;

-- 4. Allow public read access to all files in the bucket
CREATE POLICY "Public read access for miwodo-photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'miwodo-photos');

-- 5. Allow public (anon key) upload of files
CREATE POLICY "Public upload to miwodo-photos"
ON storage.objects FOR INSERT
TO public
WITH CHECK (bucket_id = 'miwodo-photos');

-- 6. Allow public update/overwrite (upsert=true needs this)
CREATE POLICY "Public update to miwodo-photos"
ON storage.objects FOR UPDATE
TO public
USING (bucket_id = 'miwodo-photos')
WITH CHECK (bucket_id = 'miwodo-photos');

-- 7. Allow public delete
CREATE POLICY "Public delete from miwodo-photos"
ON storage.objects FOR DELETE
TO public
USING (bucket_id = 'miwodo-photos');
