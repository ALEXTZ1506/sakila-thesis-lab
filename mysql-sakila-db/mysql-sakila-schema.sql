
-- Sakila Sample Database Schema
-- Version 0.8

-- Copyright (c) 2006, MySQL AB
-- All rights reserved.

-- Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

--  * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
--  * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
--  * Neither the name of MySQL AB nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

DROP SCHEMA IF EXISTS sakila;
CREATE SCHEMA sakila;
USE sakila;

--
-- Table structure for table `actor`
--

CREATE TABLE actor (
  actor_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  first_name VARCHAR(45) NOT NULL,
  last_name VARCHAR(45) NOT NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY  (actor_id),
  KEY idx_actor_last_name (last_name)
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `address`
--

CREATE TABLE address (
  address_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  address VARCHAR(50) NOT NULL,
  address2 VARCHAR(50) DEFAULT NULL,
  district VARCHAR(20) NOT NULL,
  city_id INT UNSIGNED NOT NULL,
  postal_code VARCHAR(10) DEFAULT NULL,
  phone VARCHAR(20) NOT NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY  (address_id),
  KEY idx_fk_city_id (city_id),
  CONSTRAINT `fk_address_city` FOREIGN KEY (city_id) REFERENCES city (city_id) ON DELETE RESTRICT ON UPDATE CASCADE
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `category`
--

CREATE TABLE category (
  category_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(25) NOT NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY  (category_id)
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `city`
--

CREATE TABLE city (
  city_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  city VARCHAR(50) NOT NULL,
  country_id INT UNSIGNED NOT NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY  (city_id),
  KEY idx_fk_country_id (country_id),
  CONSTRAINT `fk_city_country` FOREIGN KEY (country_id) REFERENCES country (country_id) ON DELETE RESTRICT ON UPDATE CASCADE
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `country`
--

CREATE TABLE country (
  country_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  country VARCHAR(50) NOT NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY  (country_id)
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `customer`
--

CREATE TABLE customer (
  customer_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  store_id INT UNSIGNED NOT NULL,
  first_name VARCHAR(45) NOT NULL,
  last_name VARCHAR(45) NOT NULL,
  email VARCHAR(50) DEFAULT NULL,
  address_id INT UNSIGNED NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  create_date DATETIME NOT NULL,
  last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY  (customer_id),
  KEY idx_fk_store_id (store_id),
  KEY idx_fk_address_id (address_id),
  KEY idx_last_name (last_name),
  CONSTRAINT fk_customer_address FOREIGN KEY (address_id) REFERENCES address (address_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_customer_store FOREIGN KEY (store_id) REFERENCES store (store_id) ON DELETE RESTRICT ON UPDATE CASCADE
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `film`
--

CREATE TABLE film (
  film_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  title VARCHAR(255) NOT NULL,
  description TEXT DEFAULT NULL,
  release_year YEAR DEFAULT NULL,
  language_id INT UNSIGNED NOT NULL,
  original_language_id INT UNSIGNED DEFAULT NULL,
  rental_duration TINYINT UNSIGNED NOT NULL DEFAULT 3,
  rental_rate DECIMAL(4,2) NOT NULL DEFAULT 4.99,
  length SMALLINT UNSIGNED DEFAULT NULL,
  replacement_cost DECIMAL(5,2) NOT NULL DEFAULT 19.99,
  rating ENUM('G','PG','PG-13','R','NC-17') DEFAULT 'G',
  special_features SET('Trailers','Commentaries','Deleted Scenes','Behind the Scenes') DEFAULT NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY  (film_id),
  KEY idx_title (title),
  KEY idx_fk_language_id (language_id),
  KEY idx_fk_original_language_id (original_language_id),
  CONSTRAINT fk_film_language FOREIGN KEY (language_id) REFERENCES language (language_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_film_language_original FOREIGN KEY (original_language_id) REFERENCES language (language_id) ON DELETE RESTRICT ON UPDATE CASCADE
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `film_actor`
--

CREATE TABLE film_actor (
  actor_id INT UNSIGNED NOT NULL,
  film_id INT UNSIGNED NOT NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY  (actor_id,film_id),
  KEY idx_fk_film_id (`film_id`),
  CONSTRAINT fk_film_actor_actor FOREIGN KEY (actor_id) REFERENCES actor (actor_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_film_actor_film FOREIGN KEY (film_id) REFERENCES film (film_id) ON DELETE RESTRICT ON UPDATE CASCADE
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `film_category`
--

CREATE TABLE film_category (
  film_id INT UNSIGNED NOT NULL,
  category_id INT UNSIGNED NOT NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (film_id, category_id),
  CONSTRAINT fk_film_category_film FOREIGN KEY (film_id) REFERENCES film (film_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_film_category_category FOREIGN KEY (category_id) REFERENCES category (category_id) ON DELETE RESTRICT ON UPDATE CASCADE
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `film_text`
--

CREATE TABLE film_text (
  film_id INT NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  PRIMARY KEY  (film_id),
  FULLTEXT KEY idx_title_description (title,description)
)ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Triggers for loading film_text from film
--

DELIMITER ;;
CREATE TRIGGER `ins_film` AFTER INSERT ON `film` FOR EACH ROW BEGIN
    INSERT INTO film_text (film_id, title, description)
        VALUES (new.film_id, new.title, new.description);
  END;;


CREATE TRIGGER `upd_film` AFTER UPDATE ON `film` FOR EACH ROW BEGIN
    IF (old.title != new.title) or (old.description != new.description)
    THEN
        UPDATE film_text
            SET title=new.title,
                description=new.description,
                film_id=new.film_id
        WHERE film_id=old.film_id;
    END IF;
  END;;


CREATE TRIGGER `del_film` AFTER DELETE ON `film` FOR EACH ROW BEGIN
    DELETE FROM film_text WHERE film_id = old.film_id;
  END;;

DELIMITER ;

--
-- Table structure for table `inventory`
--

CREATE TABLE inventory (
  inventory_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  film_id INT UNSIGNED NOT NULL,
  store_id INT UNSIGNED NOT NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY  (inventory_id),
  KEY idx_fk_film_id (film_id),
  KEY idx_store_id_film_id (store_id,film_id),
  CONSTRAINT fk_inventory_store FOREIGN KEY (store_id) REFERENCES store (store_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_inventory_film FOREIGN KEY (film_id) REFERENCES film (film_id) ON DELETE RESTRICT ON UPDATE CASCADE
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `language`
--

CREATE TABLE language (
  language_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name CHAR(20) NOT NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (language_id)
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `payment`
--

CREATE TABLE payment (
  payment_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id INT UNSIGNED NOT NULL,
  staff_id INT UNSIGNED NOT NULL,
  rental_id INT DEFAULT NULL,
  amount DECIMAL(5,2) NOT NULL,
  payment_date DATETIME NOT NULL,
  last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY  (payment_id),
  KEY idx_fk_staff_id (staff_id),
  KEY idx_fk_customer_id (customer_id),
  CONSTRAINT fk_payment_rental FOREIGN KEY (rental_id) REFERENCES rental (rental_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_payment_customer FOREIGN KEY (customer_id) REFERENCES customer (customer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_payment_staff FOREIGN KEY (staff_id) REFERENCES staff (staff_id) ON DELETE RESTRICT ON UPDATE CASCADE
)ENGINE=InnoDB DEFAULT CHARSET=utf8;


--
-- Table structure for table `rental`
--

CREATE TABLE rental (
  rental_id INT NOT NULL AUTO_INCREMENT,
  rental_date DATETIME NOT NULL,
  inventory_id INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NOT NULL,
  return_date DATETIME DEFAULT NULL,
  staff_id INT UNSIGNED NOT NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (rental_id),
  UNIQUE KEY  (rental_date,inventory_id,customer_id),
  KEY idx_fk_inventory_id (inventory_id),
  KEY idx_fk_customer_id (customer_id),
  KEY idx_fk_staff_id (staff_id),
  CONSTRAINT fk_rental_staff FOREIGN KEY (staff_id) REFERENCES staff (staff_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_rental_inventory FOREIGN KEY (inventory_id) REFERENCES inventory (inventory_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_rental_customer FOREIGN KEY (customer_id) REFERENCES customer (customer_id) ON DELETE RESTRICT ON UPDATE CASCADE
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `staff`
--

CREATE TABLE staff (
  staff_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  first_name VARCHAR(45) NOT NULL,
  last_name VARCHAR(45) NOT NULL,
  address_id INT UNSIGNED NOT NULL,
  picture MEDIUMBLOB DEFAULT NULL,
  email VARCHAR(50) DEFAULT NULL,
  store_id INT UNSIGNED NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  username VARCHAR(16) NOT NULL,
  password VARCHAR(40) BINARY DEFAULT NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY  (staff_id),
  KEY idx_fk_store_id (store_id),
  KEY idx_fk_address_id (address_id),
  CONSTRAINT fk_staff_store FOREIGN KEY (store_id) REFERENCES store (store_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_staff_address FOREIGN KEY (address_id) REFERENCES address (address_id) ON DELETE RESTRICT ON UPDATE CASCADE
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `store`
--

CREATE TABLE store (
  store_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  manager_staff_id INT UNSIGNED NOT NULL,
  address_id INT UNSIGNED NOT NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY  (store_id),
  UNIQUE KEY idx_unique_manager (manager_staff_id),
  KEY idx_fk_address_id (address_id),
  CONSTRAINT fk_store_staff FOREIGN KEY (manager_staff_id) REFERENCES staff (staff_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_store_address FOREIGN KEY (address_id) REFERENCES address (address_id) ON DELETE RESTRICT ON UPDATE CASCADE
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- View structure for view `customer_list`
--

CREATE VIEW customer_list
AS
SELECT cu.customer_id AS ID, CONCAT(cu.first_name, _utf8' ', cu.last_name) AS name, a.address AS address, a.postal_code AS `zip code`,
	a.phone AS phone, city.city AS city, country.country AS country, IF(cu.active, _utf8'active',_utf8'') AS notes, cu.store_id AS SID
FROM customer AS cu JOIN address AS a ON cu.address_id = a.address_id JOIN city ON a.city_id = city.city_id
	JOIN country ON city.country_id = country.country_id;

--
-- View structure for view `film_list`
--

CREATE VIEW film_list
AS
SELECT film.film_id AS FID, film.title AS title, film.description AS description, category.name AS category, film.rental_rate AS price,
	film.length AS length, film.rating AS rating, GROUP_CONCAT(CONCAT(actor.first_name, _utf8' ', actor.last_name) SEPARATOR ', ') AS actors
FROM category LEFT JOIN film_category ON category.category_id = film_category.category_id LEFT JOIN film ON film_category.film_id = film.film_id
        JOIN film_actor ON film.film_id = film_actor.film_id
	JOIN actor ON film_actor.actor_id = actor.actor_id
GROUP BY film.film_id, film.title, film.description, film.rental_rate, film.length, film.rating, category.name;

--
-- View structure for view `nicer_but_slower_film_list`
--

CREATE VIEW nicer_but_slower_film_list
AS
SELECT film.film_id AS FID, film.title AS title, film.description AS description, category.name AS category, film.rental_rate AS price,
	film.length AS length, film.rating AS rating, GROUP_CONCAT(CONCAT(CONCAT(UCASE(SUBSTR(actor.first_name,1,1)),
	LCASE(SUBSTR(actor.first_name,2,LENGTH(actor.first_name))),_utf8' ',CONCAT(UCASE(SUBSTR(actor.last_name,1,1)),
	LCASE(SUBSTR(actor.last_name,2,LENGTH(actor.last_name)))))) SEPARATOR ', ') AS actors
FROM category LEFT JOIN film_category ON category.category_id = film_category.category_id LEFT JOIN film ON film_category.film_id = film.film_id
        JOIN film_actor ON film.film_id = film_actor.film_id
	JOIN actor ON film_actor.actor_id = actor.actor_id
GROUP BY film.film_id, film.title, film.description, film.rental_rate, film.length, film.rating, category.name;

--
-- View structure for view `staff_list`
--

CREATE VIEW staff_list
AS
SELECT s.staff_id AS ID, CONCAT(s.first_name, _utf8' ', s.last_name) AS name, a.address AS address, a.postal_code AS `zip code`, a.phone AS phone,
	city.city AS city, country.country AS country, s.store_id AS SID
FROM staff AS s JOIN address AS a ON s.address_id = a.address_id JOIN city ON a.city_id = city.city_id
	JOIN country ON city.country_id = country.country_id;

--
-- View structure for view `sales_by_store`
--

CREATE VIEW sales_by_store
AS
SELECT
CONCAT(c.city, _utf8',', cy.country) AS store
, CONCAT(m.first_name, _utf8' ', m.last_name) AS manager
, SUM(p.amount) AS total_sales
FROM payment AS p
INNER JOIN rental AS r ON p.rental_id = r.rental_id
INNER JOIN inventory AS i ON r.inventory_id = i.inventory_id
INNER JOIN store AS s ON i.store_id = s.store_id
INNER JOIN address AS a ON s.address_id = a.address_id
INNER JOIN city AS c ON a.city_id = c.city_id
INNER JOIN country AS cy ON c.country_id = cy.country_id
INNER JOIN staff AS m ON s.manager_staff_id = m.staff_id
GROUP BY s.store_id
ORDER BY cy.country, c.city;

--
-- View structure for view `sales_by_film_category`
--
-- Note that total sales will add up to >100% because
-- some titles belong to more than 1 category
--

CREATE VIEW sales_by_film_category
AS
SELECT
c.name AS category
, SUM(p.amount) AS total_sales
FROM payment AS p
INNER JOIN rental AS r ON p.rental_id = r.rental_id
INNER JOIN inventory AS i ON r.inventory_id = i.inventory_id
INNER JOIN film AS f ON i.film_id = f.film_id
INNER JOIN film_category AS fc ON f.film_id = fc.film_id
INNER JOIN category AS c ON fc.category_id = c.category_id
GROUP BY c.name
ORDER BY total_sales DESC;

--
-- View structure for view `actor_info`
--

CREATE DEFINER=CURRENT_USER SQL SECURITY INVOKER VIEW actor_info
AS
SELECT
a.actor_id,
a.first_name,
a.last_name,
GROUP_CONCAT(DISTINCT CONCAT(c.name, ': ',
		(SELECT GROUP_CONCAT(f.title ORDER BY f.title SEPARATOR ', ')
                    FROM sakila.film f
                    INNER JOIN sakila.film_category fc
                      ON f.film_id = fc.film_id
                    INNER JOIN sakila.film_actor fa
                      ON f.film_id = fa.film_id
                    WHERE fc.category_id = c.category_id
                    AND fa.actor_id = a.actor_id
                 )
             )
             ORDER BY c.name SEPARATOR '; ')
AS film_info
FROM sakila.actor a
LEFT JOIN sakila.film_actor fa
  ON a.actor_id = fa.actor_id
LEFT JOIN sakila.film_category fc
  ON fa.film_id = fc.film_id
LEFT JOIN sakila.category c
  ON fc.category_id = c.category_id
GROUP BY a.actor_id, a.first_name, a.last_name;

--
-- Procedure structure for procedure `rewards_report`
--

DELIMITER //

CREATE PROCEDURE rewards_report (
    IN min_monthly_purchases TINYINT UNSIGNED
    , IN min_dollar_amount_purchased DECIMAL(10,2) UNSIGNED
    , OUT count_rewardees INT
)
LANGUAGE SQL
NOT DETERMINISTIC
READS SQL DATA
SQL SECURITY DEFINER
COMMENT 'Provides a customizable report on best customers'
proc: BEGIN

    DECLARE last_month_start DATE;
    DECLARE last_month_end DATE;

    /* Some sanity checks... */
    IF min_monthly_purchases = 0 THEN
        SELECT 'Minimum monthly purchases parameter must be > 0';
        LEAVE proc;
    END IF;
    IF min_dollar_amount_purchased = 0.00 THEN
        SELECT 'Minimum monthly dollar amount purchased parameter must be > $0.00';
        LEAVE proc;
    END IF;

    /* Determine start and end time periods */
    SET last_month_start = DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH);
    SET last_month_start = STR_TO_DATE(CONCAT(YEAR(last_month_start),'-',MONTH(last_month_start),'-01'),'%Y-%m-%d');
    SET last_month_end = LAST_DAY(last_month_start);

    /*
        Create a temporary storage area for
        Customer IDs.
    */
    CREATE TEMPORARY TABLE tmpCustomer (customer_id INT UNSIGNED NOT NULL PRIMARY KEY);

    /*
        Find all customers meeting the
        monthly purchase requirements
    */
    INSERT INTO tmpCustomer (customer_id)
    SELECT p.customer_id
    FROM payment AS p
    WHERE DATE(p.payment_date) BETWEEN last_month_start AND last_month_end
    GROUP BY customer_id
    HAVING SUM(p.amount) > min_dollar_amount_purchased
    AND COUNT(customer_id) > min_monthly_purchases;

    /* Populate OUT parameter with count of found customers */
    SELECT COUNT(*) FROM tmpCustomer INTO count_rewardees;

    /*
        Output ALL customer information of matching rewardees.
        Customize output as needed.
    */
    SELECT c.*
    FROM tmpCustomer AS t
    INNER JOIN customer AS c ON t.customer_id = c.customer_id;

    /* Clean up */
    DROP TABLE tmpCustomer;
END //

DELIMITER ;

DELIMITER $$

CREATE FUNCTION get_customer_balance(p_customer_id INT, p_effective_date DATETIME) RETURNS DECIMAL(5,2)
    DETERMINISTIC
    READS SQL DATA
BEGIN

       #OK, WE NEED TO CALCULATE THE CURRENT BALANCE GIVEN A CUSTOMER_ID AND A DATE
       #THAT WE WANT THE BALANCE TO BE EFFECTIVE FOR. THE BALANCE IS:
       #   1) RENTAL FEES FOR ALL PREVIOUS RENTALS
       #   2) ONE DOLLAR FOR EVERY DAY THE PREVIOUS RENTALS ARE OVERDUE
       #   3) IF A FILM IS MORE THAN RENTAL_DURATION * 2 OVERDUE, CHARGE THE REPLACEMENT_COST
       #   4) SUBTRACT ALL PAYMENTS MADE BEFORE THE DATE SPECIFIED

  DECLARE v_rentfees DECIMAL(5,2); #FEES PAID TO RENT THE VIDEOS INITIALLY
  DECLARE v_overfees INTEGER;      #LATE FEES FOR PRIOR RENTALS
  DECLARE v_payments DECIMAL(5,2); #SUM OF PAYMENTS MADE PREVIOUSLY

  SELECT IFNULL(SUM(film.rental_rate),0) INTO v_rentfees
    FROM film, inventory, rental
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

  SELECT IFNULL(SUM(IF((TO_DAYS(rental.return_date) - TO_DAYS(rental.rental_date)) > film.rental_duration,
        ((TO_DAYS(rental.return_date) - TO_DAYS(rental.rental_date)) - film.rental_duration),0)),0) INTO v_overfees
    FROM rental, inventory, film
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;


  SELECT IFNULL(SUM(payment.amount),0) INTO v_payments
    FROM payment

    WHERE payment.payment_date <= p_effective_date
    AND payment.customer_id = p_customer_id;

  RETURN v_rentfees + v_overfees - v_payments;
END $$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE film_in_stock(IN p_film_id INT, IN p_store_id INT, OUT p_film_count INT)
READS SQL DATA
BEGIN
     SELECT inventory_id
     FROM inventory
     WHERE film_id = p_film_id
     AND store_id = p_store_id
     AND inventory_in_stock(inventory_id);

     SELECT FOUND_ROWS() INTO p_film_count;
END $$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE film_not_in_stock(IN p_film_id INT, IN p_store_id INT, OUT p_film_count INT)
READS SQL DATA
BEGIN
     SELECT inventory_id
     FROM inventory
     WHERE film_id = p_film_id
     AND store_id = p_store_id
     AND NOT inventory_in_stock(inventory_id);

     SELECT FOUND_ROWS() INTO p_film_count;
END $$

DELIMITER ;

DELIMITER $$

CREATE FUNCTION inventory_held_by_customer(p_inventory_id INT) RETURNS INT
READS SQL DATA
BEGIN
  DECLARE v_customer_id INT;
  DECLARE EXIT HANDLER FOR NOT FOUND RETURN NULL;

  SELECT customer_id INTO v_customer_id
  FROM rental
  WHERE return_date IS NULL
  AND inventory_id = p_inventory_id;

  RETURN v_customer_id;
END $$

DELIMITER ;

DELIMITER $$

CREATE FUNCTION inventory_in_stock(p_inventory_id INT) RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_rentals INT;
    DECLARE v_out     INT;

    #AN ITEM IS IN-STOCK IF THERE ARE EITHER NO ROWS IN THE rental TABLE
    #FOR THE ITEM OR ALL ROWS HAVE return_date POPULATED

    SELECT COUNT(*) INTO v_rentals
    FROM rental
    WHERE inventory_id = p_inventory_id;

    IF v_rentals = 0 THEN
      RETURN TRUE;
    END IF;

    SELECT COUNT(rental_id) INTO v_out
    FROM inventory LEFT JOIN rental USING(inventory_id)
    WHERE inventory.inventory_id = p_inventory_id
    AND rental.return_date IS NULL;

    IF v_out > 0 THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
END $$
DELIMITER ;

-- =============================================================================
-- EXTENDED TABLES AND FEATURES FOR PERFORMANCE TESTING
-- =============================================================================

-- EXTRA TABLES FOR AUDITING AND ANALYTICS
CREATE TABLE IF NOT EXISTS audit_rental (
  audit_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  rental_id INT,
  action ENUM('INSERT','UPDATE','DELETE') NOT NULL,
  changed_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  actor_user VARCHAR(64) NULL,
  actor_host VARCHAR(128) NULL,
  before_json LONGTEXT NULL,
  after_json LONGTEXT NULL,
  KEY idx_audit_rental_rental_id (rental_id),
  KEY idx_audit_rental_changed_at (changed_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_payment (
  audit_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  payment_id INT,
  action ENUM('INSERT','UPDATE','DELETE') NOT NULL,
  changed_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  actor_user VARCHAR(64) NULL,
  actor_host VARCHAR(128) NULL,
  before_json LONGTEXT NULL,
  after_json LONGTEXT NULL,
  KEY idx_audit_payment_payment_id (payment_id),
  KEY idx_audit_payment_changed_at (changed_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sales_rollup_daily (
  sales_date DATE NOT NULL,
  store_id INT UNSIGNED NOT NULL,
  category_id INT UNSIGNED NOT NULL,
  total_sales DECIMAL(18,2) NOT NULL DEFAULT 0,
  tx_count INT UNSIGNED NOT NULL DEFAULT 0,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (sales_date, store_id, category_id),
  KEY idx_sales_rollup_date (sales_date),
  KEY idx_sales_rollup_store (store_id),
  KEY idx_sales_rollup_category (category_id),
  CONSTRAINT fk_srd_store FOREIGN KEY (store_id) REFERENCES store(store_id),
  CONSTRAINT fk_srd_cat FOREIGN KEY (category_id) REFERENCES category(category_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS customer_kpis (
  customer_id INT UNSIGNED PRIMARY KEY,
  rentals_count BIGINT UNSIGNED NOT NULL DEFAULT 0,
  active_rentals INT UNSIGNED NOT NULL DEFAULT 0,
  total_spent DECIMAL(18,2) NOT NULL DEFAULT 0,
  last_payment DATETIME NULL,
  last_rental DATETIME NULL,
  balance_cached DECIMAL(18,2) NOT NULL DEFAULT 0,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_customer_kpis_last_payment (last_payment),
  CONSTRAINT fk_ck_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS inventory_status (
  inventory_id INT UNSIGNED PRIMARY KEY,
  film_id INT UNSIGNED NOT NULL,
  store_id INT UNSIGNED NOT NULL,
  is_in_stock BOOLEAN NOT NULL,
  total_rentals INT UNSIGNED NOT NULL DEFAULT 0,
  last_rental DATETIME NULL,
  last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_inventory_status_film_store (film_id, store_id),
  KEY idx_inventory_status_stock (is_in_stock),
  CONSTRAINT fk_is_inventory FOREIGN KEY (inventory_id) REFERENCES inventory(inventory_id),
  CONSTRAINT fk_is_film FOREIGN KEY (film_id) REFERENCES film(film_id),
  CONSTRAINT fk_is_store FOREIGN KEY (store_id) REFERENCES store(store_id)
) ENGINE=InnoDB;

-- STORED PROCEDURES FOR DATA MANAGEMENT
DELIMITER $$

CREATE PROCEDURE sp_refresh_sales_rollup(IN p_start DATE, IN p_end DATE)
BEGIN
  DELETE FROM sales_rollup_daily WHERE sales_date BETWEEN p_start AND p_end;

  INSERT INTO sales_rollup_daily (sales_date, store_id, category_id, total_sales, tx_count)
  SELECT DATE(p.payment_date), s.store_id, COALESCE(fc.category_id,0),
         SUM(p.amount), COUNT(*)
  FROM payment p
  JOIN rental r      ON r.rental_id = p.rental_id
  JOIN inventory i   ON i.inventory_id = r.inventory_id
  JOIN store s       ON s.store_id = i.store_id
  LEFT JOIN film f   ON f.film_id = i.film_id
  LEFT JOIN film_category fc ON fc.film_id = f.film_id
  WHERE DATE(p.payment_date) BETWEEN p_start AND p_end
  GROUP BY DATE(p.payment_date), s.store_id, COALESCE(fc.category_id,0);
END $$

CREATE PROCEDURE sp_refresh_customer_kpis()
BEGIN
  DELETE FROM customer_kpis;

  INSERT INTO customer_kpis (customer_id, rentals_count, active_rentals, total_spent, last_payment, last_rental, balance_cached)
  SELECT
    c.customer_id,
    (SELECT COUNT(*) FROM rental r WHERE r.customer_id=c.customer_id) AS rentals_count,
    (SELECT COUNT(*) FROM rental r WHERE r.customer_id=c.customer_id AND r.return_date IS NULL) AS active_rentals,
    COALESCE((SELECT SUM(p.amount) FROM payment p WHERE p.customer_id=c.customer_id),0) AS total_spent,
    (SELECT MAX(p.payment_date) FROM payment p WHERE p.customer_id=c.customer_id) AS last_payment,
    (SELECT MAX(r.rental_date) FROM rental r WHERE r.customer_id=c.customer_id) AS last_rental,
    COALESCE((SELECT SUM(p.amount) FROM payment p WHERE p.customer_id=c.customer_id),0) AS balance_cached
  FROM customer c;
END $$

CREATE PROCEDURE sp_refresh_inventory_status()
BEGIN
  DELETE FROM inventory_status;
  INSERT INTO inventory_status(inventory_id, film_id, store_id, is_in_stock, total_rentals, last_rental)
  SELECT i.inventory_id, i.film_id, i.store_id,
         NOT EXISTS(SELECT 1 FROM rental r WHERE r.inventory_id=i.inventory_id AND r.return_date IS NULL) AS is_in_stock,
         (SELECT COUNT(*) FROM rental r WHERE r.inventory_id=i.inventory_id),
         (SELECT MAX(rental_date) FROM rental r WHERE r.inventory_id=i.inventory_id)
  FROM inventory i;
END $$

-- sp_seed_synthetic_data: genera carga sintetica de clientes, rentals y
-- payments sobre el esquema Sakila. Usado por el caso R3 (insercion masiva).
--
-- OPTIMIZACION (vs version previa con ORDER BY RAND() LIMIT 1):
--   El pick aleatorio sobre inventory/customer/staff se hace con un offset
--   aleatorio acotado por [MIN(pk), MAX(pk)] y lookup indexado por PK +
--   LIMIT 1. Complejidad O(log N) en vez de O(N log N), aproximadamente
--   30-200x mas rapido segun el tamano de inventory. Tolerante a gaps
--   en la secuencia: si el offset cae en un hueco, el >= devuelve la
--   siguiente fila existente. Misma optimizacion aplicada en el port a
--   PostgreSQL para simetria de medicion.
--
-- ROBUSTEZ FRENTE A TRIGGERS DE AUDITORIA:
--   En vez de depender de LAST_INSERT_ID() despues de INSERT INTO rental
--   (ambiguo si trg_audit_rental_insert inserta en audit_rental con su
--   propio auto-increment), capturamos rental_id via la UNIQUE KEY
--   (rental_date, inventory_id, customer_id) con un SELECT indexado.
--
-- TOLERANCIA A COLISIONES (UNIQUE KEY):
--   v_when es constante por dia y los picks aleatorios pueden repetir
--   (v_inv, v_cust). Probabilidad por colision con p_avg=100: ~0.2% por
--   iteracion (~6 colisiones esperadas en p_days=30, p_avg=100). Para no
--   abortar el procedure usamos INSERT IGNORE y verificamos ROW_COUNT();
--   si la fila ya existia, saltamos UPDATE y payment, contamos en
--   v_skipped y seguimos. Implicacion: p_avg_rentals_per_day es un
--   OBJETIVO, no garantizado; la perdida esperada es <1% para p_avg<=100.
--   El procedure reporta v_skipped al final via SELECT.
CREATE PROCEDURE sp_seed_synthetic_data(
  IN p_customers INT, IN p_days INT, IN p_avg_rentals_per_day INT
)
BEGIN
  DECLARE v INT DEFAULT 0;
  DECLARE d INT DEFAULT 0;
  DECLARE r INT;
  DECLARE v_store INT;
  DECLARE v_inv INT;
  DECLARE v_cust INT;
  DECLARE v_staff INT;
  DECLARE addr_id INT;
  DECLARE v_rental_id INT;
  DECLARE v_inv_lo  INT;
  DECLARE v_inv_hi  INT;
  DECLARE v_cust_lo INT;
  DECLARE v_cust_hi INT;
  DECLARE v_staff_lo INT;
  DECLARE v_staff_hi INT;
  DECLARE v_when DATETIME;
  DECLARE v_skipped INT DEFAULT 0;

  -- Fase 1: insertar p_customers clientes sinteticos con direccion fresca.
  WHILE v < p_customers DO
    INSERT INTO address(address, district, city_id, phone)
    VALUES (CONCAT('Addr ', UUID()), 'NA', 1, '000');
    SET addr_id = LAST_INSERT_ID();

    INSERT INTO customer(store_id, first_name, last_name, email, address_id, active, create_date)
    VALUES (1, CONCAT('C', UUID()), 'X', CONCAT(UUID(), '@ex.com'), addr_id, TRUE, NOW());
    SET v = v + 1;
  END WHILE;

  -- Capturar limites de PK DESPUES de sembrar clientes (inventory y staff son estaticos).
  SELECT MIN(inventory_id), MAX(inventory_id) INTO v_inv_lo,   v_inv_hi   FROM inventory;
  SELECT MIN(customer_id),  MAX(customer_id)  INTO v_cust_lo,  v_cust_hi  FROM customer;
  SELECT MIN(staff_id),     MAX(staff_id)     INTO v_staff_lo, v_staff_hi FROM staff;

  -- Fase 2: generar rentals y payments simulando workload diario.
  SET d = 0;
  WHILE d < p_days DO
    SET r = 0;
    -- Cache del timestamp del dia (evita 3 llamadas a NOW() por iteracion).
    SET v_when = DATE_SUB(NOW(), INTERVAL d DAY);
    WHILE r < p_avg_rentals_per_day DO
      -- Pick aleatorio sobre inventory (lookup indexado por PK).
      SELECT inventory_id, store_id INTO v_inv, v_store
      FROM inventory
      WHERE inventory_id >= v_inv_lo + FLOOR(RAND() * (v_inv_hi - v_inv_lo + 1))
      ORDER BY inventory_id
      LIMIT 1;

      -- Pick aleatorio sobre customer.
      SELECT customer_id INTO v_cust
      FROM customer
      WHERE customer_id >= v_cust_lo + FLOOR(RAND() * (v_cust_hi - v_cust_lo + 1))
      ORDER BY customer_id
      LIMIT 1;

      -- Pick aleatorio sobre staff.
      SELECT staff_id INTO v_staff
      FROM staff
      WHERE staff_id >= v_staff_lo + FLOOR(RAND() * (v_staff_hi - v_staff_lo + 1))
      ORDER BY staff_id
      LIMIT 1;

      -- INSERT IGNORE permite saltar colisiones sobre la UNIQUE KEY
      -- (rental_date, inventory_id, customer_id) sin abortar el procedure.
      INSERT IGNORE INTO rental(rental_date, inventory_id, customer_id, return_date, staff_id)
      VALUES (v_when, v_inv, v_cust, NULL, v_staff);

      IF ROW_COUNT() = 0 THEN
        -- Colision: la combinacion ya existia. Saltamos UPDATE y payment.
        SET v_skipped = v_skipped + 1;
      ELSE
        -- Capturar rental_id via UNIQUE KEY en vez de LAST_INSERT_ID() (ver header).
        SELECT rental_id INTO v_rental_id
        FROM rental
        WHERE rental_date = v_when AND inventory_id = v_inv AND customer_id = v_cust;

        -- ~50% de las rentals tienen return_date dentro de 3 dias.
        IF RAND() > 0.5 THEN
          UPDATE rental SET return_date = v_when + INTERVAL FLOOR(RAND()*3) DAY
          WHERE rental_id = v_rental_id;
        END IF;

        INSERT INTO payment(customer_id, staff_id, rental_id, amount, payment_date)
        VALUES (v_cust, v_staff, v_rental_id, ROUND(2.99 + (RAND()*7), 2), v_when);
      END IF;

      SET r = r + 1;
    END WHILE;
    SET d = d + 1;
  END WHILE;

  -- Reporte de observabilidad para evidencia en logs de R3.
  SELECT v_skipped AS rows_skipped_due_to_collision;
END $$

-- sp_random_workload: genera workload mixto lectura/escritura para los
-- casos R2 (OLTP 80/20) y R5 (carga sostenida 10 min). Cada iteracion
-- ejecuta Q1 (agregado pesado), Q2 (full-text) y Q3 (UPDATE de 10
-- payments aleatorios via TEMP TABLE). El port a PostgreSQL vive en
-- ../postgres-sakila-db/postgres-sakila-schema.sql con la misma logica.
CREATE PROCEDURE sp_random_workload(IN p_iters INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  DECLARE k INT;
  DECLARE v_pay_lo INT;
  DECLARE v_pay_hi INT;

  -- Capturar limites de payment_id una sola vez. Acepta sesgo menor si
  -- otras sesiones insertan payments concurrentemente durante la
  -- ejecucion (los nuevos payment_id no se sampleran). Compromise
  -- consciente para evitar 2 queries adicionales por iteracion.
  SELECT MIN(payment_id), MAX(payment_id) INTO v_pay_lo, v_pay_hi FROM payment;

  WHILE i < p_iters DO
    -- Q1: agregado pesado sobre customer + rental + payment.
    SELECT c.customer_id, COUNT(r.rental_id) AS cnt, COALESCE(SUM(p.amount),0) AS amt
    FROM customer c
    LEFT JOIN rental r ON r.customer_id=c.customer_id
    LEFT JOIN payment p ON p.customer_id=c.customer_id
    GROUP BY c.customer_id
    ORDER BY amt DESC
    LIMIT 200;

    -- Q2: busqueda full-text sobre film_text (MyISAM + FULLTEXT).
    SELECT f.film_id, f.title
    FROM film f
    JOIN film_text ft ON ft.film_id=f.film_id
    WHERE MATCH(ft.title, ft.description) AGAINST('action love' IN NATURAL LANGUAGE MODE)
    ORDER BY f.rental_rate DESC
    LIMIT 100;

    -- Q3: UPDATE de 10 payments ALEATORIOS via TEMP TABLE.
    -- Mejora deliberada sobre el comportamiento heredado (que tomaba
    -- los 10 payment_id mas altos): evita concentrar todas las
    -- escrituras de R5 en los mismos 10 payments y distribuye la
    -- carga de auditoria sobre el espacio completo de payment_id.
    -- Tecnica identica a sp_seed_synthetic_data: offset aleatorio
    -- acotado por [MIN, MAX] + lookup indexado por PK + LIMIT 1,
    -- repetido 10 veces. INSERT IGNORE absorbe picks duplicados
    -- (probabilidad <1 en 50K para payment ~513K).
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_recent_payments (
      payment_id INT UNSIGNED PRIMARY KEY
    );

    DELETE FROM temp_recent_payments;

    SET k = 0;
    WHILE k < 10 DO
      INSERT IGNORE INTO temp_recent_payments
      SELECT payment_id FROM payment
      WHERE payment_id >= v_pay_lo + FLOOR(RAND() * (v_pay_hi - v_pay_lo + 1))
      ORDER BY payment_id
      LIMIT 1;
      SET k = k + 1;
    END WHILE;

    UPDATE payment p
    JOIN temp_recent_payments tmp ON p.payment_id = tmp.payment_id
    SET p.amount = p.amount + 0.01;

    DROP TEMPORARY TABLE temp_recent_payments;

    SET i = i + 1;
  END WHILE;
END $$

DELIMITER ;

-- MANUAL DATA POPULATION PROCEDURE (Run this AFTER loading original data)
DELIMITER $$

CREATE PROCEDURE sp_populate_extended_tables()
BEGIN
  CALL sp_refresh_customer_kpis();
  CALL sp_refresh_inventory_status();
  CALL sp_refresh_sales_rollup('2005-01-01', '2012-12-31');
END $$

DELIMITER ;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;