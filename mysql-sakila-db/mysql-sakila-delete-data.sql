-- =============================================================================
-- SCRIPT: Delete Data (MariaDB)
-- OBJETIVO: vaciar TODOS los datos dejando la estructura intacta (tablas,
--   vistas, procedures, triggers). Util para resetear entre corridas sin
--   recargar el esquema.
--
-- Cubre las tablas canonicas de Sakila + las extendidas de la tesis
-- (audit_rental, audit_payment, sales_rollup_daily, customer_kpis,
-- inventory_status). Las tablas de auditoria se vacian al FINAL: si los
-- triggers complementarios estan activos, los DELETE sobre rental/payment las
-- repueblan, asi que limpiarlas de ultimo garantiza que queden vacias.
--
-- Se desactivan los chequeos de FK para que el orden de borrado no importe.
-- =============================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- Tablas transaccionales y de dimension (Sakila canonico)
DELETE FROM payment;
DELETE FROM rental;
DELETE FROM customer;
DELETE FROM film_category;
DELETE FROM film_text;
DELETE FROM film_actor;
DELETE FROM inventory;
DELETE FROM film;
DELETE FROM category;
DELETE FROM staff;
DELETE FROM store;
DELETE FROM actor;
DELETE FROM address;
DELETE FROM city;
DELETE FROM country;
DELETE FROM language;

-- Tablas extendidas (no auditoria)
DELETE FROM sales_rollup_daily;
DELETE FROM customer_kpis;
DELETE FROM inventory_status;

-- Tablas de auditoria al FINAL (ver cabecera)
DELETE FROM audit_payment;
DELETE FROM audit_rental;

SET FOREIGN_KEY_CHECKS = 1;
