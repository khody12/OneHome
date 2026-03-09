-- Emoji reactions on posts
CREATE TABLE post_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(post_id, user_id, emoji)
);

ALTER TABLE post_reactions ENABLE ROW LEVEL SECURITY;

-- Home members can read reactions on posts in their home
CREATE POLICY "home members can read reactions"
    ON post_reactions FOR SELECT
    USING (
        post_id IN (
            SELECT id FROM posts
            WHERE home_id IN (
                SELECT home_id FROM home_members WHERE user_id = auth.uid()
            )
        )
    );

-- Home members can insert their own reactions
CREATE POLICY "home members can insert own reactions"
    ON post_reactions FOR INSERT
    WITH CHECK (
        user_id = auth.uid()
        AND post_id IN (
            SELECT id FROM posts
            WHERE home_id IN (
                SELECT home_id FROM home_members WHERE user_id = auth.uid()
            )
        )
    );

-- Users can delete only their own reactions
CREATE POLICY "users can delete own reactions"
    ON post_reactions FOR DELETE
    USING (user_id = auth.uid());
