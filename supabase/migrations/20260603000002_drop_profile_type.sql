-- Remove profile type column — the concept is no longer exposed in the UI.
ALTER TABLE profiles DROP COLUMN IF EXISTS type;
