-- =============================================================================
-- SCRIPT: Extend Audit Tables (PostgreSQL)
-- OBJECTIVE: Bring existing audit_rental / audit_payment tables up to the
--            schema required by the application-level audit triggers.
--
-- WHEN TO RUN:
--   Run this ONCE on any environment whose base schema was loaded BEFORE
--   actor_host was added to the canonical schema. The four lab VMs
--   (TUS-MariaDB, TUS-MariaDB-Audit, TUS-PostgreSQL, TUS-PostgreSQL-Audit)
--   fall in this bucket because they were loaded with the original
--   audit_* definitions and ~513K rows have already been inserted via the
--   inflation script.
--
--   Fresh installations do NOT need this script: the canonical
--   postgres-sakila-schema.sql already includes the change, so a new
--   environment is born in the target state.
--
-- WHAT THIS SCRIPT DOES:
--   Adds actor_host VARCHAR(128) NULL on both audit_* tables.
--   Rationale: forensic columns for cases S1 (SQL injection) and S5
--   (data exfiltration), where the attacker typically reuses legitimate
--   application credentials but connects from an unexpected host.
--
--   No TIMESTAMP precision change is needed for PostgreSQL: the default
--   TIMESTAMP type already stores microsecond precision (matching what
--   the MariaDB side achieves only after upgrading to TIMESTAMP(6) via
--   mysql-sakila-extend-audit.sql).
--
-- IDEMPOTENCY:
--   ADD COLUMN IF NOT EXISTS (PostgreSQL 9.6+) makes the script safe to
--   re-run. If the column already exists, PostgreSQL emits a NOTICE and
--   continues without error.
-- =============================================================================

ALTER TABLE audit_rental  ADD COLUMN IF NOT EXISTS actor_host VARCHAR(128) NULL;
ALTER TABLE audit_payment ADD COLUMN IF NOT EXISTS actor_host VARCHAR(128) NULL;

DO $$
BEGIN
    RAISE NOTICE 'extend-audit: actor_host column ensured on audit_rental and audit_payment';
END$$;
