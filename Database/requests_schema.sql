-- Requests feature: adds request-specific columns to the posts table.
-- Requests are not a separate table — they are posts with category = 'request'
-- and these extra nullable columns.

ALTER TABLE posts ADD COLUMN IF NOT EXISTS requested_user_ids UUID[] DEFAULT NULL;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS completion_post_id UUID REFERENCES posts(id) ON DELETE SET NULL DEFAULT NULL;
