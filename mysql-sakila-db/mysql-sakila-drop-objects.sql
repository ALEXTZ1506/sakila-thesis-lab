-- =============================================================================
-- SCRIPT: Drop Objects (MariaDB)
-- OBJETIVO: eliminar TODOS los objetos del esquema sakila (tablas, vistas,
--   procedures y funciones), tanto los canonicos de Sakila como los
--   extendidos de la tesis. Idempotente (IF EXISTS) y a prueba de orden de
--   FK (FOREIGN_KEY_CHECKS=0). Los triggers trg_audit_* caen junto con sus
--   tablas (rental/payment), por lo que no se listan aparte.
--
-- Tras correr este script el esquema `sakila` queda vacio de objetos pero
-- sigue existiendo. Para recrearlo, ejecutar mysql-sakila-schema.sql.
-- =============================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- Vistas
DROP VIEW IF EXISTS
  customer_list, film_list, nicer_but_slower_film_list, staff_list,
  sales_by_store, sales_by_film_category, actor_info;

-- Tablas: extendidas + auditoria primero, luego canonicas
DROP TABLE IF EXISTS
  audit_payment, audit_rental, sales_rollup_daily, customer_kpis, inventory_status,
  payment, rental, inventory, film_text, film_category, film_actor, film,
  customer, store, staff, address, city, country, category, language, actor;

SET FOREIGN_KEY_CHECKS = 1;

-- Procedures y funciones (Sakila canonico)
DROP PROCEDURE IF EXISTS rewards_report;
DROP PROCEDURE IF EXISTS film_in_stock;
DROP PROCEDURE IF EXISTS film_not_in_stock;
DROP FUNCTION  IF EXISTS get_customer_balance;
DROP FUNCTION  IF EXISTS inventory_held_by_customer;
DROP FUNCTION  IF EXISTS inventory_in_stock;

-- Procedures extendidos de la tesis
DROP PROCEDURE IF EXISTS sp_refresh_sales_rollup;
DROP PROCEDURE IF EXISTS sp_refresh_customer_kpis;
DROP PROCEDURE IF EXISTS sp_refresh_inventory_status;
DROP PROCEDURE IF EXISTS sp_populate_extended_tables;
DROP PROCEDURE IF EXISTS sp_seed_synthetic_data;
DROP PROCEDURE IF EXISTS sp_random_workload;
