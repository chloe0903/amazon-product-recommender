USE Amazon;

-- ============================================================================
-- 1. Stored Procedure: sp_get_top_products_in_category
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_get_top_products_in_category;

DELIMITER //

CREATE PROCEDURE sp_get_top_products_in_category(IN cat_name VARCHAR(255))
BEGIN
    IF cat_name IS NULL OR cat_name = '' OR cat_name = 'All Categories' THEN
        SELECT 
            p.asin, 
            p.product_name, 
            c.category_name, 
            AVG(pr.rating) as avg_rating, 
            COUNT(pr.rating) as review_count
        FROM product p
        JOIN category c ON p.category_id = c.category_id
        JOIN product_review pr ON p.asin = pr.asin
        GROUP BY p.asin, p.product_name, c.category_name
        HAVING review_count > 5
        ORDER BY avg_rating DESC, review_count DESC
        LIMIT 10;
    ELSE
        SELECT 
            p.asin, 
            p.product_name, 
            c.category_name, 
            AVG(pr.rating) as avg_rating, 
            COUNT(pr.rating) as review_count
        FROM product p
        JOIN category c ON p.category_id = c.category_id
        JOIN product_review pr ON p.asin = pr.asin
        WHERE c.category_name = cat_name
        GROUP BY p.asin, p.product_name, c.category_name
        HAVING review_count > 5
        ORDER BY avg_rating DESC, review_count DESC
        LIMIT 10;
    END IF;
END //

DELIMITER ;

-- ============================================================================
-- 2. Transaction: sp_purchase_product
-- ============================================================================

CREATE TABLE IF NOT EXISTS inventory (
    asin VARCHAR(20) PRIMARY KEY,
    quantity INT DEFAULT 100,
    FOREIGN KEY (asin) REFERENCES product(asin) ON DELETE CASCADE
) ENGINE=InnoDB;

INSERT IGNORE INTO inventory (asin, quantity)
SELECT asin, FLOOR(10 + RAND() * 90) FROM product;

DROP PROCEDURE IF EXISTS sp_purchase_product;

DELIMITER //

CREATE PROCEDURE sp_purchase_product(
    IN p_buyer_id VARCHAR(255), 
    IN p_asin VARCHAR(20),
    OUT p_status VARCHAR(50)
)
BEGIN
    DECLARE current_stock INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status = 'ERROR: Transaction Failed';
    END;

    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    START TRANSACTION;

    SELECT quantity INTO current_stock 
    FROM inventory 
    WHERE asin = p_asin 
    FOR UPDATE;

    IF current_stock > 0 THEN
        UPDATE inventory SET quantity = quantity - 1 WHERE asin = p_asin;

        INSERT INTO buyer_purchase (buyer_id, asin, purchased_at)
        VALUES (p_buyer_id, p_asin, NOW());

        COMMIT;
        SET p_status = 'SUCCESS: Purchased';
    ELSE
        ROLLBACK;
        SET p_status = 'FAIL: Out of Stock';
    END IF;
END //

DELIMITER ;

-- ============================================================================
-- 3. Trigger: trg_update_avg_rating
-- ============================================================================

-- Add column if not exists
SET @dbname = DATABASE();
SET @tablename = "product";
SET @columnname = "last_activity";
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (table_name = @tablename)
      AND (table_schema = @dbname)
      AND (column_name = @columnname)
  ) > 0,
  "SELECT 1",
  "ALTER TABLE product ADD COLUMN last_activity DATETIME DEFAULT NULL;"
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

DROP TRIGGER IF EXISTS trg_after_review_insert;

DELIMITER //

CREATE TRIGGER trg_after_review_insert
AFTER INSERT ON product_review
FOR EACH ROW
BEGIN
    IF NEW.rating >= 1 AND NEW.rating <= 5 THEN
        UPDATE product 
        SET last_activity = NOW() 
        WHERE asin = NEW.asin;
    END IF;
END //

DELIMITER ;
