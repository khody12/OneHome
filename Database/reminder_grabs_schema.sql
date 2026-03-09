-- Add current_claimer_id to household_reminders
ALTER TABLE household_reminders
    ADD COLUMN IF NOT EXISTS current_claimer_id uuid REFERENCES auth.users(id);

-- Grab history: one row per "I'll grab it" claim
CREATE TABLE IF NOT EXISTS reminder_grabs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reminder_id uuid NOT NULL REFERENCES household_reminders(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id),
    grabbed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE reminder_grabs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "home members can read grabs" ON reminder_grabs FOR SELECT USING (
    reminder_id IN (
        SELECT hr.id FROM household_reminders hr
        JOIN home_members hm ON hm.home_id = hr.home_id
        WHERE hm.user_id = auth.uid()
    )
);

CREATE POLICY "home members can insert grabs" ON reminder_grabs FOR INSERT WITH CHECK (
    reminder_id IN (
        SELECT hr.id FROM household_reminders hr
        JOIN home_members hm ON hm.home_id = hr.home_id
        WHERE hm.user_id = auth.uid()
    )
);
