-- =============================================================================
-- SCRIPT: Drop Objects (PostgreSQL)
-- OBJETIVO: eliminar TODOS los objetos del esquema public (tablas, vistas,
--   funciones, procedures, agregados, secuencias, dominios y tipos), tanto
--   los canonicos de Pagila como los extendidos de la tesis. Idempotente
--   (IF EXISTS) y a prueba de dependencias (CASCADE).
--
-- NOTA: varios objetos caen por CASCADE al dropear las tablas de las que
-- dependen (p.ej. la funcion rewards_report depende de la tabla `customer`,
-- y los triggers trg_audit_* caen con sus tablas). El IF EXISTS hace que los
-- DROP explicitos posteriores no fallen aunque el objeto ya se haya ido por
-- cascada. Las particiones hijas de payment caen con `DROP TABLE payment`.
-- =============================================================================

-- Vistas
DROP VIEW IF EXISTS
    customer_list, film_list, nicer_but_slower_film_list,
    sales_by_film_category, sales_by_store, staff_list, actor_info CASCADE;

-- Tablas extendidas + auditoria
DROP TABLE IF EXISTS
    audit_rental, audit_payment, sales_rollup_daily,
    customer_kpis, inventory_status CASCADE;

-- Tablas base (CASCADE arrastra particiones hijas, FKs y objetos dependientes)
DROP TABLE IF EXISTS
    payment, rental, inventory, film_category, film_actor, film,
    language, customer, actor, category, store, address, staff,
    city, country CASCADE;

-- Funciones y procedures de Pagila canonico
DROP FUNCTION  IF EXISTS film_in_stock(integer, integer);
DROP FUNCTION  IF EXISTS film_not_in_stock(integer, integer);
DROP FUNCTION  IF EXISTS get_customer_balance(integer, timestamp without time zone);
DROP FUNCTION  IF EXISTS inventory_held_by_customer(integer);
DROP FUNCTION  IF EXISTS inventory_in_stock(integer);
DROP FUNCTION  IF EXISTS last_day(timestamp without time zone);
DROP FUNCTION  IF EXISTS rewards_report(integer, numeric);
DROP FUNCTION  IF EXISTS last_updated() CASCADE;
DROP AGGREGATE IF EXISTS group_concat(text);
DROP FUNCTION  IF EXISTS _group_concat(text, text) CASCADE;

-- Objetos extendidos de la tesis (procedures + funcion de auditoria)
DROP FUNCTION  IF EXISTS fn_audit_row() CASCADE;
DROP PROCEDURE IF EXISTS sp_refresh_sales_rollup(date, date);
DROP PROCEDURE IF EXISTS sp_refresh_customer_kpis();
DROP PROCEDURE IF EXISTS sp_refresh_inventory_status();
DROP PROCEDURE IF EXISTS sp_populate_extended_tables();
DROP PROCEDURE IF EXISTS sp_seed_synthetic_data(integer, integer, integer);
DROP PROCEDURE IF EXISTS sp_random_workload(integer);

-- Secuencias
DROP SEQUENCE IF EXISTS
    actor_actor_id_seq, address_address_id_seq, category_category_id_seq,
    city_city_id_seq, country_country_id_seq, customer_customer_id_seq,
    film_film_id_seq, inventory_inventory_id_seq, language_language_id_seq,
    payment_payment_id_seq, rental_rental_id_seq, staff_staff_id_seq,
    store_store_id_seq CASCADE;

-- Dominios y tipos
DROP DOMAIN IF EXISTS year;
DROP TYPE   IF EXISTS mpaa_rating;

-- Extension pgcrypto (la crea setup.md / Q03; se recrea con CREATE EXTENSION
-- IF NOT EXISTS). Se elimina aqui para que el teardown deje el schema public
-- realmente vacio. Sus ~36 funciones (digest, gen_salt, pgp_*, etc.) viven en
-- public y de lo contrario quedarian residuales.
DROP EXTENSION IF EXISTS pgcrypto;
