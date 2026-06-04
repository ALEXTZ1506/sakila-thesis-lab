-- =============================================================================
-- SCRIPT: Application-Level Audit Triggers (PostgreSQL)
-- OBJECTIVE: Implement the application-level audit mechanism that the thesis
--            compares against the engine-level pgAudit extension.
--
-- METHODOLOGICAL ROLE:
--   The thesis (Chapter III) contrasts THREE audit configurations per engine:
--     1. No auditing (baseline)
--     2. Engine-level plugin (MariaDB Audit Plugin / pgAudit)
--     3. Application-level triggers writing to audit_* tables  <-- THIS FILE
--   These triggers materialize configuration (3) on PostgreSQL. The MariaDB
--   counterpart lives at ../mysql-sakila-db/mysql-sakila-audit-triggers.sql
--   and uses one independent trigger per (table, event) pair because MySQL
--   triggers cannot be shared.
--
-- AUDITED TABLES AND EVENTS:
--   rental                                  -> INSERT, UPDATE, DELETE   (3 triggers)
--   payment (parent)                        -> INSERT, UPDATE, DELETE   (3 triggers)
--   payment_p2007_01 .. payment_p2007_06    -> INSERT, UPDATE, DELETE   (18 triggers)
--   Total: 24 triggers, all delegating to a single PL/pgSQL function
--          fn_audit_row(). The function discriminates target table and
--          operation via TG_TABLE_NAME and TG_OP, which keeps the code
--          DRY and behaviorally aligned across triggers (any future
--          change is applied once).
--
-- COLUMN POPULATION:
--   rental_id / payment_id : NEW.* for INSERT/UPDATE, OLD.* for DELETE
--   action                 : TG_OP literal ('INSERT' | 'UPDATE' | 'DELETE')
--   changed_at             : populated via DEFAULT CURRENT_TIMESTAMP
--                            (PostgreSQL TIMESTAMP is microsecond-precision
--                            by default, matching TIMESTAMP(6) on MariaDB)
--   actor_user             : current_user                                    -- 'role'
--   actor_host             : COALESCE(inet_client_addr()::text,'local-socket')
--                            ('local-socket' marker for Unix socket conns
--                            where inet_client_addr() returns NULL)
--   before_json            : NULL for INSERT, to_jsonb(OLD)::text otherwise
--   after_json             : NULL for DELETE, to_jsonb(NEW)::text otherwise
--
-- IDEMPOTENCY:
--   CREATE OR REPLACE FUNCTION is idempotent by definition. Each
--   CREATE TRIGGER is preceded by DROP TRIGGER IF EXISTS so re-running this
--   file is safe and replaces the previous definitions atomically per
--   trigger.
--
-- PARTITION COVERAGE STRATEGY:
--   The `payment` table is partitioned via the legacy INHERITS+RULES
--   mechanism (children payment_p2007_01..06). A trigger on the parent
--   `payment` only fires for rows that physically reside in the parent
--   table -- it does NOT fire for DML targeting rows that live in child
--   partitions. To preserve full-coverage symmetry with MariaDB (where
--   `payment` is a single un-partitioned table and every event is captured
--   unconditionally), we attach the same 3 triggers to each of the 6
--   child partitions (18 additional triggers, 21 total for the payment
--   family). All triggers delegate to fn_audit_row(); the function routes
--   to audit_payment when TG_TABLE_NAME equals 'payment' OR matches the
--   Pagila partition naming pattern '^payment_p[0-9]{4}_[0-9]{2}$'.
--
-- KNOWN OVERHEAD (measured by the thesis):
--   Each DML on rental/payment forces one additional row insert into
--   audit_*. This is the cost the thesis attributes to "auditoria aplicativa"
--   and measures against the pgAudit-based alternative under loads R1-R5.
-- =============================================================================

-- ---------------------------------------------------------
-- UNIFIED AUDIT FUNCTION
-- ---------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_audit_row() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_action TEXT := TG_OP;
    v_user   TEXT := current_user;
    v_host   TEXT := COALESCE(inet_client_addr()::text, 'local-socket');
    v_before JSONB;
    v_after  JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_before := NULL;
        v_after  := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_before := to_jsonb(OLD);
        v_after  := to_jsonb(NEW);
    ELSIF TG_OP = 'DELETE' THEN
        v_before := to_jsonb(OLD);
        v_after  := NULL;
    END IF;

    IF TG_TABLE_NAME = 'rental' THEN
        INSERT INTO audit_rental (
            rental_id, action, actor_user, actor_host, before_json, after_json
        ) VALUES (
            CASE WHEN TG_OP = 'DELETE' THEN OLD.rental_id ELSE NEW.rental_id END,
            v_action, v_user, v_host,
            v_before::text, v_after::text
        );
    ELSIF TG_TABLE_NAME = 'payment'
       OR TG_TABLE_NAME ~ '^payment_p[0-9]{4}_[0-9]{2}$' THEN
        INSERT INTO audit_payment (
            payment_id, action, actor_user, actor_host, before_json, after_json
        ) VALUES (
            CASE WHEN TG_OP = 'DELETE' THEN OLD.payment_id ELSE NEW.payment_id END,
            v_action, v_user, v_host,
            v_before::text, v_after::text
        );
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- ---------------------------------------------------------
-- RENTAL TRIGGERS
-- ---------------------------------------------------------

-- trg_audit_rental_insert: records every new rental.
--   Relevant for R3 (bulk insert) and any workload generating rental rows.
DROP TRIGGER IF EXISTS trg_audit_rental_insert ON rental;
CREATE TRIGGER trg_audit_rental_insert
    AFTER INSERT ON rental
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

-- trg_audit_rental_update: records modifications. Crucial for cases where
--   the attacker alters return_date to mask theft of physical inventory.
DROP TRIGGER IF EXISTS trg_audit_rental_update ON rental;
CREATE TRIGGER trg_audit_rental_update
    AFTER UPDATE ON rental
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

-- trg_audit_rental_delete: records deletions. Primary detection vector for
--   case S5 (data exfiltration via tamper-and-delete patterns).
DROP TRIGGER IF EXISTS trg_audit_rental_delete ON rental;
CREATE TRIGGER trg_audit_rental_delete
    AFTER DELETE ON rental
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

-- ---------------------------------------------------------
-- TRIGGERS SOBRE PAYMENT PARENT (cobertura activa)
-- Estos triggers se disparan para la mayoria de eventos de payment
-- porque las RULES INSERT de Pagila solo redirigen filas cuya
-- payment_date cae en 2007-01..06; las filas fuera de ese rango
-- (inserciones infladas de 2008-2011, eventos generados por el
-- workload con fecha actual, etc.) aterrizan en la tabla payment
-- parent y se auditan aqui. UPDATE y DELETE no tienen RULES
-- definidas y se disparan sobre la tabla donde fisicamente reside
-- la fila afectada, asi que este trigger tambien captura todas
-- las modificaciones a filas residentes en parent.
-- ---------------------------------------------------------

-- trg_audit_payment_insert: registra cada nuevo payment. Pesado bajo R3.
DROP TRIGGER IF EXISTS trg_audit_payment_insert ON payment;
CREATE TRIGGER trg_audit_payment_insert
    AFTER INSERT ON payment
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

-- trg_audit_payment_update: captures modifications to payment.amount,
--   fundamental for cases S4 (malicious DDL) and S5 (exfiltration with
--   price tampering).
DROP TRIGGER IF EXISTS trg_audit_payment_update ON payment;
CREATE TRIGGER trg_audit_payment_update
    AFTER UPDATE ON payment
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

-- trg_audit_payment_delete: captures deletions. Detection vector for cases
--   where the attacker erases payments after a fraudulent refund.
DROP TRIGGER IF EXISTS trg_audit_payment_delete ON payment;
CREATE TRIGGER trg_audit_payment_delete
    AFTER DELETE ON payment
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

-- ---------------------------------------------------------
-- TRIGGERS SOBRE PARTICIONES HIJAS (cobertura complementaria)
-- Cubren los INSERT redirigidos por las RULES de Pagila para
-- payment_date en 2007-01..06, asi como los UPDATE/DELETE sobre
-- filas que fisicamente residen en cada particion.
-- ---------------------------------------------------------

DROP TRIGGER IF EXISTS trg_audit_payment_insert ON payment_p2007_01;
CREATE TRIGGER trg_audit_payment_insert AFTER INSERT ON payment_p2007_01 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();
DROP TRIGGER IF EXISTS trg_audit_payment_update ON payment_p2007_01;
CREATE TRIGGER trg_audit_payment_update AFTER UPDATE ON payment_p2007_01 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();
DROP TRIGGER IF EXISTS trg_audit_payment_delete ON payment_p2007_01;
CREATE TRIGGER trg_audit_payment_delete AFTER DELETE ON payment_p2007_01 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

DROP TRIGGER IF EXISTS trg_audit_payment_insert ON payment_p2007_02;
CREATE TRIGGER trg_audit_payment_insert AFTER INSERT ON payment_p2007_02 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();
DROP TRIGGER IF EXISTS trg_audit_payment_update ON payment_p2007_02;
CREATE TRIGGER trg_audit_payment_update AFTER UPDATE ON payment_p2007_02 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();
DROP TRIGGER IF EXISTS trg_audit_payment_delete ON payment_p2007_02;
CREATE TRIGGER trg_audit_payment_delete AFTER DELETE ON payment_p2007_02 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

DROP TRIGGER IF EXISTS trg_audit_payment_insert ON payment_p2007_03;
CREATE TRIGGER trg_audit_payment_insert AFTER INSERT ON payment_p2007_03 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();
DROP TRIGGER IF EXISTS trg_audit_payment_update ON payment_p2007_03;
CREATE TRIGGER trg_audit_payment_update AFTER UPDATE ON payment_p2007_03 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();
DROP TRIGGER IF EXISTS trg_audit_payment_delete ON payment_p2007_03;
CREATE TRIGGER trg_audit_payment_delete AFTER DELETE ON payment_p2007_03 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

DROP TRIGGER IF EXISTS trg_audit_payment_insert ON payment_p2007_04;
CREATE TRIGGER trg_audit_payment_insert AFTER INSERT ON payment_p2007_04 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();
DROP TRIGGER IF EXISTS trg_audit_payment_update ON payment_p2007_04;
CREATE TRIGGER trg_audit_payment_update AFTER UPDATE ON payment_p2007_04 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();
DROP TRIGGER IF EXISTS trg_audit_payment_delete ON payment_p2007_04;
CREATE TRIGGER trg_audit_payment_delete AFTER DELETE ON payment_p2007_04 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

DROP TRIGGER IF EXISTS trg_audit_payment_insert ON payment_p2007_05;
CREATE TRIGGER trg_audit_payment_insert AFTER INSERT ON payment_p2007_05 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();
DROP TRIGGER IF EXISTS trg_audit_payment_update ON payment_p2007_05;
CREATE TRIGGER trg_audit_payment_update AFTER UPDATE ON payment_p2007_05 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();
DROP TRIGGER IF EXISTS trg_audit_payment_delete ON payment_p2007_05;
CREATE TRIGGER trg_audit_payment_delete AFTER DELETE ON payment_p2007_05 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

DROP TRIGGER IF EXISTS trg_audit_payment_insert ON payment_p2007_06;
CREATE TRIGGER trg_audit_payment_insert AFTER INSERT ON payment_p2007_06 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();
DROP TRIGGER IF EXISTS trg_audit_payment_update ON payment_p2007_06;
CREATE TRIGGER trg_audit_payment_update AFTER UPDATE ON payment_p2007_06 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();
DROP TRIGGER IF EXISTS trg_audit_payment_delete ON payment_p2007_06;
CREATE TRIGGER trg_audit_payment_delete AFTER DELETE ON payment_p2007_06 FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

DO $$
BEGIN
    RAISE NOTICE '24 audit triggers installed: 3 on rental, 3 on payment, 18 on payment_p2007_01..06 (function: fn_audit_row).';
END$$;
