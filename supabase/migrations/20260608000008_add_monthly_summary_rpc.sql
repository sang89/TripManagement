-- Server-side monthly aggregation for the finances overview chart and banner.
-- Returns one row per month instead of transferring all raw transaction rows.
CREATE OR REPLACE FUNCTION get_monthly_transaction_summary(
  p_profile_id uuid DEFAULT NULL
)
RETURNS TABLE(
  month          date,
  total_income   numeric,
  total_expenses numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    date_trunc('month', date)::date                                    AS month,
    SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END)::numeric   AS total_income,
    SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END)::numeric   AS total_expenses
  FROM  financial_transactions
  WHERE user_id  = auth.uid()
    AND status   = 'active'
    AND (p_profile_id IS NULL OR profile_id = p_profile_id)
  GROUP BY date_trunc('month', date)
  ORDER BY 1;
$$;

GRANT EXECUTE ON FUNCTION get_monthly_transaction_summary(uuid) TO authenticated;
