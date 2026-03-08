-- OneHome Storage Setup
-- Run this in your Supabase SQL editor AFTER schema.sql has been applied.
-- Creates the storage bucket and RLS policies for post images.

-- Step 1: Create the bucket
-- You can also do this via Supabase Dashboard > Storage > New Bucket:
--   Name: post-images
--   Public: true  (so image URLs work without auth headers in SwiftUI AsyncImage)
insert into storage.buckets (id, name, public) values ('post-images', 'post-images', true)
on conflict do nothing;

-- Step 2: Storage RLS policies

-- Authenticated home members can upload images to the bucket
create policy "Members can upload post images"
on storage.objects for insert
with check (bucket_id = 'post-images' and auth.role() = 'authenticated');

-- Anyone (including unauthenticated) can view images — needed for AsyncImage
create policy "Anyone can view post images"
on storage.objects for select
using (bucket_id = 'post-images');

-- Authors can only delete their own images
-- Path structure is {homeID}/{userID}/{postID}.jpg, so folder[2] is the userID segment
create policy "Authors can delete own post images"
on storage.objects for delete
using (bucket_id = 'post-images' and auth.uid()::text = (storage.foldername(name))[2]);
