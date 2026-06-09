-- financial_transactions: compound index for the main paginated query + RPC
CREATE INDEX IF NOT EXISTS ft_user_status_date_idx ON financial_transactions (user_id, status, date DESC);
CREATE INDEX IF NOT EXISTS ft_profile_id_idx ON financial_transactions (profile_id) WHERE profile_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ft_bank_account_id_idx ON financial_transactions (bank_account_id) WHERE bank_account_id IS NOT NULL;

-- properties
CREATE INDEX IF NOT EXISTS properties_user_id_idx ON properties (user_id);
CREATE INDEX IF NOT EXISTS properties_profile_id_idx ON properties (profile_id) WHERE profile_id IS NOT NULL;

-- child tables (FKs used in RLS sub-selects)
CREATE INDEX IF NOT EXISTS mortgages_property_id_idx ON mortgages (property_id);
CREATE INDEX IF NOT EXISTS insurances_property_id_idx ON insurances (property_id);
CREATE INDEX IF NOT EXISTS repairs_property_id_idx ON repairs (property_id);
CREATE INDEX IF NOT EXISTS house_info_items_property_id_idx ON house_info_items (property_id);

-- contractors
CREATE INDEX IF NOT EXISTS contractors_user_id_idx ON contractors (user_id);
CREATE INDEX IF NOT EXISTS contractors_profile_id_idx ON contractors (profile_id) WHERE profile_id IS NOT NULL;

-- tenants + rent_payments
CREATE INDEX IF NOT EXISTS tenants_property_id_idx ON tenants (property_id);
CREATE INDEX IF NOT EXISTS rent_payments_tenant_id_idx ON rent_payments (tenant_id);
CREATE INDEX IF NOT EXISTS rent_payments_property_id_idx ON rent_payments (property_id);

-- rental_applications
CREATE INDEX IF NOT EXISTS rental_applications_user_id_idx ON rental_applications (user_id);
CREATE INDEX IF NOT EXISTS rental_applications_property_id_idx ON rental_applications (property_id);
CREATE INDEX IF NOT EXISTS application_members_application_id_idx ON application_members (application_id);
CREATE INDEX IF NOT EXISTS application_documents_application_id_idx ON application_documents (application_id);

-- bank connections/accounts
CREATE INDEX IF NOT EXISTS bank_connections_user_id_idx ON bank_connections (user_id);
CREATE INDEX IF NOT EXISTS bank_accounts_bank_connection_id_idx ON bank_accounts (bank_connection_id);
CREATE INDEX IF NOT EXISTS bank_accounts_user_id_idx ON bank_accounts (user_id);

-- user_payment_methods
CREATE INDEX IF NOT EXISTS user_payment_methods_user_id_idx ON user_payment_methods (user_id);
