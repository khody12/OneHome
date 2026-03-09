CREATE TABLE household_reminders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  home_id uuid NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
  name text NOT NULL,
  emoji text NOT NULL DEFAULT '📦',
  interval_days int NOT NULL DEFAULT 7,
  last_cleared_at timestamptz,
  last_cleared_by_user_id uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by_user_id uuid NOT NULL REFERENCES auth.users(id)
);
ALTER TABLE household_reminders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "home members can read" ON household_reminders FOR SELECT USING (
  home_id IN (SELECT home_id FROM home_members WHERE user_id = auth.uid())
);
CREATE POLICY "home members can insert" ON household_reminders FOR INSERT WITH CHECK (
  home_id IN (SELECT home_id FROM home_members WHERE user_id = auth.uid())
);
CREATE POLICY "home members can update" ON household_reminders FOR UPDATE USING (
  home_id IN (SELECT home_id FROM home_members WHERE user_id = auth.uid())
);
CREATE POLICY "home members can delete" ON household_reminders FOR DELETE USING (
  home_id IN (SELECT home_id FROM home_members WHERE user_id = auth.uid())
);
