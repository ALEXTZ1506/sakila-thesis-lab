-- =============================================================================
-- SCRIPT: Extend Audit Tables (MariaDB)
-- OBJECTIVE: Bring existing audit_rental / audit_payment tables up to the
--            schema required by the application-level audit triggers.
--
-- WHEN TO RUN:
--   Run this ONCE on any environment whose base schema was loaded BEFORE
--   actor_host and TIMESTAMP(6) were added to the canonical schema. The
--   four lab VMs (TUS-MariaDB, TUS-MariaDB-Audit, TUS-PostgreSQL,
--   TUS-PostgreSQL-Audit) fall in this bucket because they were loaded with
--   the original audit_* definitions and ~513K rows have already been
--   inserted via the inflation script.
--
--   Fresh installations do NOT need this script: the canonical
--   mysql-sakila-schema.sql already includes both changes, so a new
--   environment is born in the target state.
--
-- WHAT THIS SCRIPT DOES:
--   1. Upgrades audit_rental.changed_at and audit_payment.changed_at from
--      TIMESTAMP (second precision) to TIMESTAMP(6) (microsecond precision).
--      Rationale: restores symmetry with PostgreSQL's default microsecond
--      precision, prevents collisions on concurrent triggers under R5
--      (30-minute sustained load).
--   2. Adds actor_host VARCHAR(128) NULL on both audit_* tables.
--      Rationale: forensic columns for cases S1 (SQL injection) and S5
--      (data exfiltration), where the attacker typically reuses legitimate
--      application credentials but connects from an unexpected host.
--
-- IDEMPOTENCY:
--   The whole script is wrapped in a one-shot stored procedure that
--   inspects information_schema and applies each ALTER only if it is still
--   needed. Re-running the script is safe and reports
--   'already applied, nothing to do'.
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_extend_audit_apply;

DELIMITER $$
CREATE PROCEDURE sp_extend_audit_apply()
BEGIN
    DECLARE v_db            VARCHAR(64);
    DECLARE v_precision     INT;
    DECLARE v_host_exists   INT;
    DECLARE v_applied_count INT DEFAULT 0;

    SET v_db = DATABASE();

    -- ---- audit_rental.changed_at -> TIMESTAMP(6) ----
    SELECT DATETIME_PRECISION INTO v_precision
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = v_db
      AND TABLE_NAME   = 'audit_rental'
      AND COLUMN_NAME  = 'changed_at';

    IF v_precision IS NOT NULL AND v_precision <> 6 THEN
        ALTER TABLE audit_rental
            MODIFY changed_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6);
        SET v_applied_count = v_applied_count + 1;
    END IF;

    -- ---- audit_payment.changed_at -> TIMESTAMP(6) ----
    SET v_precision = NULL;
    SELECT DATETIME_PRECISION INTO v_precision
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = v_db
      AND TABLE_NAME   = 'audit_payment'
      AND COLUMN_NAME  = 'changed_at';

    IF v_precision IS NOT NULL AND v_precision <> 6 THEN
        ALTER TABLE audit_payment
            MODIFY changed_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6);
        SET v_applied_count = v_applied_count + 1;
    END IF;

    -- ---- audit_rental.actor_host (add if missing) ----
    SELECT COUNT(*) INTO v_host_exists
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = v_db
      AND TABLE_NAME   = 'audit_rental'
      AND COLUMN_NAME  = 'actor_host';

    IF v_host_exists = 0 THEN
        ALTER TABLE audit_rental
            ADD COLUMN actor_host VARCHAR(128) NULL AFTER actor_user;
        SET v_applied_count = v_applied_count + 1;
    END IF;

    -- ---- audit_payment.actor_host (add if missing) ----
    SET v_host_exists = 0;
    SELECT COUNT(*) INTO v_host_exists
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = v_db
      AND TABLE_NAME   = 'audit_payment'
      AND COLUMN_NAME  = 'actor_host';

    IF v_host_exists = 0 THEN
        ALTER TABLE audit_payment
            ADD COLUMN actor_host VARCHAR(128) NULL AFTER actor_user;
        SET v_applied_count = v_applied_count + 1;
    END IF;

    IF v_applied_count = 0 THEN
        SELECT 'extend-audit: already applied, nothing to do' AS status;
    ELSE
        SELECT CONCAT('extend-audit: applied ', v_applied_count, ' alteration(s)') AS status;
    END IF;
END$$
DELIMITER ;

CALL sp_extend_audit_apply();
DROP PROCEDURE sp_extend_audit_apply;
