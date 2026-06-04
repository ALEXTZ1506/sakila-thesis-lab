-- =============================================================================
-- SCRIPT: Application-Level Audit Triggers (MariaDB)
-- OBJECTIVE: Implement the application-level audit mechanism that the thesis
--            compares against the engine-level MariaDB Audit Plugin.
--
-- METHODOLOGICAL ROLE:
--   The thesis (Chapter III) contrasts THREE audit configurations per engine:
--     1. No auditing (baseline)
--     2. Engine-level plugin (MariaDB Audit Plugin / pgAudit)
--     3. Application-level triggers writing to audit_* tables  <-- THIS FILE
--   These triggers materialize configuration (3) on MariaDB. The PostgreSQL
--   counterpart lives at ../postgres-sakila-db/postgres-sakila-audit-triggers.sql
--   and uses an equivalent unified function pattern.
--
-- AUDITED TABLES AND EVENTS:
--   rental  -> INSERT, UPDATE, DELETE  (3 triggers)
--   payment -> INSERT, UPDATE, DELETE  (3 triggers)
--   Total:   6 triggers.
--
-- COLUMN POPULATION:
--   rental_id / payment_id : NEW.* for INSERT/UPDATE, OLD.* for DELETE
--   action                 : 'INSERT' | 'UPDATE' | 'DELETE' (literal per trigger)
--   changed_at             : populated via DEFAULT CURRENT_TIMESTAMP(6)
--   actor_user             : CURRENT_USER()                  -> 'user@host'
--   actor_host             : SUBSTRING_INDEX(USER(), '@', -1) -> host fragment
--   before_json            : NULL for INSERT, JSON_OBJECT(OLD.*) otherwise
--   after_json             : NULL for DELETE, JSON_OBJECT(NEW.*) otherwise
--
-- NOTE ON actor_user AND actor_host IN MARIADB:
--   In MariaDB, CURRENT_USER() returns the string 'user@host', so
--   actor_user already implicitly carries the connection host. The
--   actor_host column (populated with SUBSTRING_INDEX(USER(), '@', -1))
--   is therefore redundant on this engine but is preserved for schema
--   symmetry with PostgreSQL, where current_user returns only the role
--   name and actor_host is the sole source of connection origin (via
--   inet_client_addr()). Forensic queries against MariaDB audit_* can
--   use either actor_host or SUBSTRING_INDEX(actor_user,'@',-1)
--   interchangeably; against PostgreSQL audit_*, only actor_host carries
--   the host.
--
-- IDEMPOTENCY:
--   DROP TRIGGER IF EXISTS precedes every CREATE TRIGGER, so re-running this
--   file is safe and replaces the previous definitions atomically per
--   trigger.
--
-- KNOWN OVERHEAD (measured by the thesis):
--   Each DML on rental/payment forces one additional row insert into audit_*.
--   This is the cost the thesis attributes to "auditoría aplicativa" and
--   measures against the plugin-based alternative under loads R1-R5.
-- =============================================================================

-- ---------------------------------------------------------
-- RENTAL TRIGGERS
-- ---------------------------------------------------------

-- trg_audit_rental_insert: records every new rental.
--   Relevant for R3 (bulk insert) and any workload generating rental rows.
DROP TRIGGER IF EXISTS trg_audit_rental_insert;
DELIMITER $$
CREATE TRIGGER trg_audit_rental_insert
AFTER INSERT ON rental
FOR EACH ROW
BEGIN
    INSERT INTO audit_rental (
        rental_id, action, actor_user, actor_host, before_json, after_json
    ) VALUES (
        NEW.rental_id,
        'INSERT',
        CURRENT_USER(),
        SUBSTRING_INDEX(USER(), '@', -1),
        NULL,
        JSON_OBJECT(
            'rental_id',    NEW.rental_id,
            'rental_date',  NEW.rental_date,
            'inventory_id', NEW.inventory_id,
            'customer_id',  NEW.customer_id,
            'return_date',  NEW.return_date,
            'staff_id',     NEW.staff_id,
            'last_update',  NEW.last_update
        )
    );
END$$
DELIMITER ;

-- trg_audit_rental_update: records modifications. Crucial for cases where
--   the attacker alters return_date to mask theft of physical inventory.
DROP TRIGGER IF EXISTS trg_audit_rental_update;
DELIMITER $$
CREATE TRIGGER trg_audit_rental_update
AFTER UPDATE ON rental
FOR EACH ROW
BEGIN
    INSERT INTO audit_rental (
        rental_id, action, actor_user, actor_host, before_json, after_json
    ) VALUES (
        NEW.rental_id,
        'UPDATE',
        CURRENT_USER(),
        SUBSTRING_INDEX(USER(), '@', -1),
        JSON_OBJECT(
            'rental_id',    OLD.rental_id,
            'rental_date',  OLD.rental_date,
            'inventory_id', OLD.inventory_id,
            'customer_id',  OLD.customer_id,
            'return_date',  OLD.return_date,
            'staff_id',     OLD.staff_id,
            'last_update',  OLD.last_update
        ),
        JSON_OBJECT(
            'rental_id',    NEW.rental_id,
            'rental_date',  NEW.rental_date,
            'inventory_id', NEW.inventory_id,
            'customer_id',  NEW.customer_id,
            'return_date',  NEW.return_date,
            'staff_id',     NEW.staff_id,
            'last_update',  NEW.last_update
        )
    );
END$$
DELIMITER ;

-- trg_audit_rental_delete: records deletions. Primary detection vector for
--   case S5 (data exfiltration via tamper-and-delete patterns).
DROP TRIGGER IF EXISTS trg_audit_rental_delete;
DELIMITER $$
CREATE TRIGGER trg_audit_rental_delete
AFTER DELETE ON rental
FOR EACH ROW
BEGIN
    INSERT INTO audit_rental (
        rental_id, action, actor_user, actor_host, before_json, after_json
    ) VALUES (
        OLD.rental_id,
        'DELETE',
        CURRENT_USER(),
        SUBSTRING_INDEX(USER(), '@', -1),
        JSON_OBJECT(
            'rental_id',    OLD.rental_id,
            'rental_date',  OLD.rental_date,
            'inventory_id', OLD.inventory_id,
            'customer_id',  OLD.customer_id,
            'return_date',  OLD.return_date,
            'staff_id',     OLD.staff_id,
            'last_update',  OLD.last_update
        ),
        NULL
    );
END$$
DELIMITER ;

-- ---------------------------------------------------------
-- PAYMENT TRIGGERS
-- ---------------------------------------------------------

-- trg_audit_payment_insert: records every new payment. Heavy under R3.
DROP TRIGGER IF EXISTS trg_audit_payment_insert;
DELIMITER $$
CREATE TRIGGER trg_audit_payment_insert
AFTER INSERT ON payment
FOR EACH ROW
BEGIN
    INSERT INTO audit_payment (
        payment_id, action, actor_user, actor_host, before_json, after_json
    ) VALUES (
        NEW.payment_id,
        'INSERT',
        CURRENT_USER(),
        SUBSTRING_INDEX(USER(), '@', -1),
        NULL,
        JSON_OBJECT(
            'payment_id',   NEW.payment_id,
            'customer_id',  NEW.customer_id,
            'staff_id',     NEW.staff_id,
            'rental_id',    NEW.rental_id,
            'amount',       NEW.amount,
            'payment_date', NEW.payment_date,
            'last_update',  NEW.last_update
        )
    );
END$$
DELIMITER ;

-- trg_audit_payment_update: captures modifications to payment.amount,
--   fundamental for cases S4 (malicious DDL) and S5 (exfiltration with
--   price tampering).
DROP TRIGGER IF EXISTS trg_audit_payment_update;
DELIMITER $$
CREATE TRIGGER trg_audit_payment_update
AFTER UPDATE ON payment
FOR EACH ROW
BEGIN
    INSERT INTO audit_payment (
        payment_id, action, actor_user, actor_host, before_json, after_json
    ) VALUES (
        NEW.payment_id,
        'UPDATE',
        CURRENT_USER(),
        SUBSTRING_INDEX(USER(), '@', -1),
        JSON_OBJECT(
            'payment_id',   OLD.payment_id,
            'customer_id',  OLD.customer_id,
            'staff_id',     OLD.staff_id,
            'rental_id',    OLD.rental_id,
            'amount',       OLD.amount,
            'payment_date', OLD.payment_date,
            'last_update',  OLD.last_update
        ),
        JSON_OBJECT(
            'payment_id',   NEW.payment_id,
            'customer_id',  NEW.customer_id,
            'staff_id',     NEW.staff_id,
            'rental_id',    NEW.rental_id,
            'amount',       NEW.amount,
            'payment_date', NEW.payment_date,
            'last_update',  NEW.last_update
        )
    );
END$$
DELIMITER ;

-- trg_audit_payment_delete: captures deletions. Detection vector for cases
--   where the attacker erases payments after a fraudulent refund.
DROP TRIGGER IF EXISTS trg_audit_payment_delete;
DELIMITER $$
CREATE TRIGGER trg_audit_payment_delete
AFTER DELETE ON payment
FOR EACH ROW
BEGIN
    INSERT INTO audit_payment (
        payment_id, action, actor_user, actor_host, before_json, after_json
    ) VALUES (
        OLD.payment_id,
        'DELETE',
        CURRENT_USER(),
        SUBSTRING_INDEX(USER(), '@', -1),
        JSON_OBJECT(
            'payment_id',   OLD.payment_id,
            'customer_id',  OLD.customer_id,
            'staff_id',     OLD.staff_id,
            'rental_id',    OLD.rental_id,
            'amount',       OLD.amount,
            'payment_date', OLD.payment_date,
            'last_update',  OLD.last_update
        ),
        NULL
    );
END$$
DELIMITER ;

SELECT '6 audit triggers installed on rental and payment.' AS status;
