-- Add profile avatar support: an avatar_url column on users, plus a public
-- Supabase Storage bucket (and RLS policies on storage.objects) to host the
-- uploaded images. This migration only adds the DB/storage foundation --
-- the Flutter-side image picker and upload UI are implemented separately.

-- =============================================================================
-- Task 1: avatar_url column
-- =============================================================================
-- Stores the public URL of the user's uploaded avatar image (populated after
-- the image is uploaded to the `avatars` Storage bucket below). NULL until
-- the user uploads an avatar; the app falls back to an initials/icon
-- placeholder when this is NULL.
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- =============================================================================
-- Task 2: `avatars` Storage bucket
-- =============================================================================
-- Public bucket: avatar images are non-sensitive and need to be displayable
-- everywhere in the app (chat, tasks, tickets, team members, etc.) via a
-- plain public URL, without generating signed URLs per view.
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Object path convention: <user_id>/<filename>, e.g.
--   550e8400-e29b-41d4-a716-446655440000/avatar.jpg
-- i.e. the FIRST path segment of the object's `name` (the path within the
-- `avatars` bucket -- NOT including the bucket name itself, which is already
-- the separate `bucket_id` column) is always the uploading user's auth.uid().
-- storage.foldername(name) splits that path into an array of folder
-- segments, so (storage.foldername(name))[1] is that user-id segment.
-- The filename portion is intentionally unconstrained by these policies, so
-- the upload implementation is free to use a fixed name (e.g. always
-- "avatar.jpg", overwritten on each upload) or a unique name per upload --
-- whichever convention the Dart upload code adopts, ownership is enforced by
-- the same first-path-segment check either way.

-- Anyone (including anonymous/unauthenticated requests) can read avatar
-- objects, since the bucket is public and avatars must render for any
-- viewer in the app.
DROP POLICY IF EXISTS avatars_public_select ON storage.objects;
CREATE POLICY avatars_public_select
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'avatars');

-- An authenticated user may only upload into their own user-id folder.
DROP POLICY IF EXISTS avatars_owner_insert ON storage.objects;
CREATE POLICY avatars_owner_insert
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- An authenticated user may only update objects in their own user-id folder.
DROP POLICY IF EXISTS avatars_owner_update ON storage.objects;
CREATE POLICY avatars_owner_update
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- An authenticated user may only delete objects in their own user-id folder.
DROP POLICY IF EXISTS avatars_owner_delete ON storage.objects;
CREATE POLICY avatars_owner_delete
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
