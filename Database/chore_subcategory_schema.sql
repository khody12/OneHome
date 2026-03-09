-- Chore subcategory column for posts
-- Run after requests_schema.sql

ALTER TABLE posts ADD COLUMN IF NOT EXISTS chore_subcategory text;
