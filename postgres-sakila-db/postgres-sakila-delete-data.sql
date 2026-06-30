-- =============================================================================
-- SCRIPT: Delete Data (PostgreSQL)
-- OBJETIVO: vaciar TODOS los datos dejando la estructura intacta. Util para
--   resetear entre corridas sin recargar el esquema.
--
-- Se usa TRUNCATE ... RESTART IDENTITY CASCADE porque:
--   * CASCADE resuelve el orden de las claves foraneas automaticamente;
--   * TRUNCATE sobre `payment` (sin ONLY) vacia tambien sus particiones hijas
--     payment_p2007_01..06;
--   * TRUNCATE NO dispara los triggers de fila, asi que las tablas audit_*
--     no se repueblan aunque los triggers complementarios esten activos;
--   * RESTART IDENTITY reinicia las secuencias a su valor inicial.
--
-- Cubre tablas canonicas de Sakila + extendidas de la tesis (audit_rental,
-- audit_payment, sales_rollup_daily, customer_kpis, inventory_status).
-- =============================================================================

TRUNCATE TABLE
    audit_rental,
    audit_payment,
    sales_rollup_daily,
    customer_kpis,
    inventory_status,
    payment,
    rental,
    inventory,
    film_actor,
    film_category,
    film,
    customer,
    store,
    staff,
    address,
    city,
    country,
    category,
    language,
    actor
RESTART IDENTITY CASCADE;
