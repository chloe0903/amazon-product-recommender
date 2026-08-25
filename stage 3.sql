-- Schema: Amazon (store / category / product / buyer / product_review / buyer_purchase)

DROP DATABASE IF EXISTS Amazon;
CREATE DATABASE Amazon;
USE Amazon;

-- reviews
DROP TABLE IF EXISTS stg_reviews;
CREATE TABLE stg_reviews (
  rating            DECIMAL(2,1)       NULL,     -- e.g., 4.5
  title             TEXT               NULL,
  text              LONGTEXT           NULL,
  images            LONGTEXT           NULL,     -- keep raw list text for staging
  asin              VARCHAR(32)        NULL,
  parent_asin       VARCHAR(32)        NULL,
  user_id           VARCHAR(64)        NULL,
  timestamp_raw     BIGINT             NULL,     -- unix time as number
  verified_purchase TINYINT(1)         NULL,     -- 0/1
  helpful_vote      INT                NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- products - 添加 asin 列
DROP TABLE IF EXISTS stg_products;
CREATE TABLE stg_products (
  asin            VARCHAR(32)  NULL,     -- 添加这一列！
  parent_asin     VARCHAR(32)  NULL,
  title           TEXT         NULL,
  main_category   VARCHAR(255) NULL,
  average_rating  DECIMAL(3,2) NULL,
  rating_number   INT          NULL,
  features        LONGTEXT     NULL,  -- keep raw list text
  description     LONGTEXT     NULL,
  price           DECIMAL(10,2) NULL,
  images          LONGTEXT     NULL,
  videos          LONGTEXT     NULL,
  store           VARCHAR(255) NULL,
  categories      LONGTEXT     NULL,
  details         LONGTEXT     NULL,  -- raw dict text
  bought_together LONGTEXT     NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- reviews
TRUNCATE TABLE stg_reviews;

LOAD DATA LOCAL INFILE '/Users/zkx/Desktop/cs411_stage3/Video_Games.csv'
INTO TABLE stg_reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
-- raw columns into variables where needed
(rating, title, text, images, asin, parent_asin, user_id, @ts, @hv, @vp)  -- 注意：helpful_vote和verified_purchase顺序调换了！
SET
  verified_purchase = CASE LOWER(@vp)
                        WHEN 'true' THEN 1
                        WHEN 'false' THEN 0
                        WHEN 'y' THEN 1
                        WHEN 'n' THEN 0
                        WHEN '1' THEN 1
                        WHEN '0' THEN 0
                        ELSE NULL
                      END,
  helpful_vote = CASE
                   WHEN @hv REGEXP '^[0-9]+$' THEN CAST(@hv AS UNSIGNED)
                   WHEN LOWER(@hv) = 'true'  THEN 1
                   WHEN LOWER(@hv) = 'false' THEN 0
                   ELSE NULL
                 END,
  timestamp_raw =
    CASE
      -- 10-digit seconds epoch
      WHEN @ts REGEXP '^[0-9]{10}$' THEN CAST(@ts AS UNSIGNED)
      -- 13-digit milliseconds epoch -> seconds
      WHEN @ts REGEXP '^[0-9]{13}$' THEN FLOOR(CAST(@ts AS UNSIGNED)/1000)
      -- ISO datetime with milliseconds (NEW!) - 你的数据格式
      WHEN @ts REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]+$'
        THEN UNIX_TIMESTAMP(LEFT(@ts, 19))  -- 截取前19个字符，去掉毫秒
      -- ISO datetime without milliseconds
      WHEN @ts REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
        THEN UNIX_TIMESTAMP(@ts)
      -- ISO datetime with 'T'
      WHEN @ts REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'
        THEN UNIX_TIMESTAMP(REPLACE(LEFT(@ts, 19), 'T', ' '))
      -- ISO date only
      WHEN @ts REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN UNIX_TIMESTAMP(@ts)
      -- Amazon "MM DD, YYYY"
      WHEN @ts REGEXP '^[0-9]{2} [0-9]{2}, [0-9]{4}$'
        THEN UNIX_TIMESTAMP(STR_TO_DATE(@ts, '%m %d, %Y'))
      ELSE NULL
    END;

-- products - 匹配你的CSV列顺序
TRUNCATE TABLE stg_products;

LOAD DATA LOCAL INFILE '/Users/zkx/Desktop/cs411_stage3/meta_Video_Games.csv'
INTO TABLE stg_products
CHARACTER SET utf8mb4
FIELDS 
    TERMINATED BY ',' 
    ENCLOSED BY '"'
    ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
-- CSV列顺序: asin, parent_asin, title, main_category, average_rating, rating_number,
--            features, description, price, images, videos, store, categories, details, bought_together
(asin, parent_asin, title, main_category, average_rating, rating_number,
 features, description, price, images, videos, store, categories, details, bought_together);

-- 验证数据
SELECT COUNT(*) as total_rows FROM stg_products;
SELECT COUNT(*) as total_reviews FROM stg_reviews;

SELECT * FROM stg_products LIMIT 5;
SELECT * FROM stg_reviews LIMIT 5;
    
-- SELECT COUNT(*), COUNT(rating), COUNT(asin) FROM stg_reviews;

-- SELECT rating, COUNT(*) FROM stg_reviews GROUP BY rating ORDER BY rating;

-- SELECT * FROM stg_reviews WHERE asin IS NULL LIMIT 5;


-- SELECT COUNT(*) total,
--        SUM(verified_purchase IS NULL) vp_nulls,
--        SUM(helpful_vote IS NULL) hv_nulls,
--        SUM(timestamp_raw IS NULL) ts_nulls
-- FROM stg_reviews;

-- SELECT rating, verified_purchase, helpful_vote, timestamp_raw
-- FROM stg_reviews
-- WHERE verified_purchase IS NULL OR helpful_vote IS NULL OR timestamp_raw IS NULL
-- LIMIT 20;
-- select * from stg_reviews limit 100


-- ============================================================================
-- 修改后的表结构：使用原始ID作为主键
-- ============================================================================



-- 删除旧表
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS buyer_purchase;
DROP TABLE IF EXISTS product_review;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS buyer;
DROP TABLE IF EXISTS category;
DROP TABLE IF EXISTS store;

-- 1) STORE - 使用 store_name 作为主键
CREATE TABLE store (
  store_id     VARCHAR(255) NOT NULL,
  PRIMARY KEY (store_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 2) CATEGORY
CREATE TABLE category (
  category_id   INT NOT NULL AUTO_INCREMENT,
  category_name VARCHAR(255) NOT NULL,
  PRIMARY KEY (category_id),
  UNIQUE KEY uk_category_category_name (category_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 3) BUYER - 使用 user_id 作为主键
CREATE TABLE buyer (
  buyer_id   VARCHAR(255) NOT NULL,
  PRIMARY KEY (buyer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 4) PRODUCT - 使用 asin 作为主键
CREATE TABLE product (
  asin         VARCHAR(20) NOT NULL,
  product_name VARCHAR(255) NOT NULL,
  store_id     VARCHAR(255) NOT NULL,
  category_id  INT NOT NULL,
  PRIMARY KEY (asin),
  KEY idx_product_store_id (store_id),
  KEY idx_product_category_id (category_id),
  CONSTRAINT fk_product_store
    FOREIGN KEY (store_id) REFERENCES store (store_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_product_category
    FOREIGN KEY (category_id) REFERENCES category (category_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 5) PRODUCT_REVIEW - 使用复合主键 (asin, buyer_id, timestamp)
CREATE TABLE product_review (
  asin        VARCHAR(20)   NOT NULL,
  buyer_id    VARCHAR(255)  NOT NULL,
  `timestamp` DATETIME      NOT NULL,
  content     TEXT          NOT NULL,
  rating      DECIMAL(2,1)  NOT NULL,
  PRIMARY KEY (asin, buyer_id, timestamp),
  KEY idx_review_buyer_id (buyer_id),
  KEY idx_review_asin (asin),
  CONSTRAINT chk_review_rating CHECK (rating >= 1.0 AND rating <= 5.0),
  CONSTRAINT fk_review_buyer
    FOREIGN KEY (buyer_id) REFERENCES buyer (buyer_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_review_product
    FOREIGN KEY (asin) REFERENCES product (asin)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 6) BUYER_PURCHASE - 使用 asin 而不是 product_id
CREATE TABLE buyer_purchase (
  buyer_id     VARCHAR(255) NOT NULL,
  asin         VARCHAR(20)  NOT NULL,
  purchased_at DATETIME     NOT NULL,
  PRIMARY KEY (buyer_id, asin, purchased_at),
  KEY idx_purchase_asin (asin),
  CONSTRAINT fk_purchase_buyer
    FOREIGN KEY (buyer_id) REFERENCES buyer (buyer_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_purchase_product
    FOREIGN KEY (asin) REFERENCES product (asin)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================================================
-- ETL: 从 staging 表导入到正式表
-- ============================================================================

-- ============================================================================
-- 1) 导入 STORE
-- ============================================================================
INSERT INTO store (store_id)
SELECT store_id
FROM (
    SELECT DISTINCT COALESCE(NULLIF(TRIM(store), ''), 'Unknown Store') AS store_id
    FROM stg_products
) AS new_store
ON DUPLICATE KEY UPDATE store_id = new_store.store_id;

INSERT INTO category (category_name)
SELECT category_name
FROM (
    SELECT DISTINCT 
        COALESCE(NULLIF(TRIM(main_category), ''), 'Uncategorized') AS category_name
    FROM stg_products
) AS new_cat
ON DUPLICATE KEY UPDATE category_name = new_cat.category_name;


INSERT INTO buyer (buyer_id)
SELECT buyer_id
FROM (
    SELECT DISTINCT user_id AS buyer_id
    FROM stg_reviews
    WHERE user_id IS NOT NULL
      AND TRIM(user_id) != ''
) AS new_buyer
ON DUPLICATE KEY UPDATE buyer_id = new_buyer.buyer_id;


INSERT INTO product (asin, product_name, store_id, category_id)
SELECT asin, product_name, store_id, category_id
FROM (
    SELECT DISTINCT
        sp.asin,
        COALESCE(
            NULLIF(SUBSTRING(sp.title, 1, 255), ''),
            CONCAT('Product ', sp.asin)
        ) AS product_name,
        COALESCE(NULLIF(TRIM(sp.store), ''), 'Unknown Store') AS store_id,
        COALESCE(
            c.category_id,
            (SELECT category_id FROM category WHERE category_name = 'Uncategorized')
        ) AS category_id
    FROM stg_products sp
    LEFT JOIN category c
      ON c.category_name = COALESCE(NULLIF(TRIM(sp.main_category), ''), 'Uncategorized')
    WHERE sp.asin IS NOT NULL
      AND TRIM(sp.asin) != ''
      AND LENGTH(sp.asin) <= 20
) AS new_product
ON DUPLICATE KEY UPDATE
    product_name = new_product.product_name,
    store_id     = new_product.store_id,
    category_id  = new_product.category_id;

-- 添加在 reviews 中出现但不在 products 中的 asin
INSERT INTO product (asin, product_name, store_id, category_id)
SELECT asin, product_name, store_id, category_id
FROM (
    SELECT DISTINCT
        sr.asin,
        CONCAT('Product ', sr.asin) AS product_name,
        'Unknown Store' AS store_id,
        (
            SELECT category_id
            FROM category
            WHERE category_name = 'Uncategorized'
        ) AS category_id
    FROM stg_reviews sr
    WHERE sr.asin IS NOT NULL
      AND TRIM(sr.asin) != ''
      AND LENGTH(sr.asin) <= 20
      AND NOT EXISTS (
          SELECT 1 FROM product p WHERE p.asin = sr.asin
      )
) AS new_product
ON DUPLICATE KEY UPDATE
    asin = new_product.asin;



INSERT INTO product_review (asin, buyer_id, timestamp, content, rating)
SELECT asin, buyer_id, timestamp, content, rating
FROM (
    SELECT
        sr.asin,
        sr.user_id AS buyer_id,
        FROM_UNIXTIME(sr.timestamp_raw) AS timestamp,
        COALESCE(
            NULLIF(TRIM(CONCAT_WS(' - ', sr.title, sr.text)), ''),
            COALESCE(sr.text, sr.title, 'No content')
        ) AS content,
        sr.rating
    FROM stg_reviews sr
    INNER JOIN buyer b
        ON b.buyer_id = sr.user_id
    INNER JOIN product p
        ON p.asin = sr.asin
    WHERE sr.rating IS NOT NULL
      AND sr.timestamp_raw IS NOT NULL
      AND sr.rating BETWEEN 1.0 AND 5.0
      AND sr.asin IS NOT NULL
      AND sr.user_id IS NOT NULL
) AS new_review
ON DUPLICATE KEY UPDATE
    content = new_review.content,
    rating  = new_review.rating;


INSERT INTO buyer_purchase (buyer_id, asin, purchased_at)
SELECT buyer_id, asin, purchased_at
FROM (
    SELECT DISTINCT
        sr.user_id AS buyer_id,
        sr.asin,
        FROM_UNIXTIME(sr.timestamp_raw) AS purchased_at
    FROM stg_reviews sr
    INNER JOIN buyer b
        ON b.buyer_id = sr.user_id
    INNER JOIN product p
        ON p.asin = sr.asin
    WHERE sr.verified_purchase = 1
      AND sr.timestamp_raw IS NOT NULL
      AND sr.asin IS NOT NULL
      AND sr.user_id IS NOT NULL
) AS new_purchase
ON DUPLICATE KEY UPDATE
    purchased_at = new_purchase.purchased_at;


select count(*) as buyer_purchase_count from buyer_purchase;
select count(*) as product_review_count from product_review;
select count(*) as product_count from product;
select count(*) as buyer_count from buyer;
select count(*) as category_count from category;
select count(*) as store_count from store;

SHOW DATABASES;
USE amazon;
SHOW TABLES;
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 

SELECT
    c.category_name,
    COUNT(*) AS review_cnt,
    ROUND(AVG(pr.rating), 2) AS avg_rating
FROM product_review pr
JOIN product p      ON pr.asin = p.asin
JOIN category c     ON p.category_id = c.category_id
WHERE pr.rating IS NOT NULL
  AND pr.rating > 0
  AND category_name <> 'Uncategorized'
GROUP BY c.category_id, c.category_name
HAVING COUNT(*) >= 100
ORDER BY avg_rating DESC, review_cnt DESC
LIMIT 15;


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
EXPLAIN ANALYZE
SELECT
    c.category_name,
    COUNT(*) AS review_cnt,
    ROUND(AVG(pr.rating), 2) AS avg_rating
FROM product_review pr
JOIN product p      ON pr.asin = p.asin
JOIN category c     ON p.category_id = c.category_id
WHERE pr.rating IS NOT NULL
  AND pr.rating > 0
GROUP BY c.category_id, c.category_name
HAVING COUNT(*) >= 100
ORDER BY avg_rating DESC, review_cnt DESC
LIMIT 15;

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
CREATE INDEX idx_pr_rating_asin ON product_review (rating, asin);

EXPLAIN ANALYZE
SELECT
    c.category_name,
    COUNT(*) AS review_cnt,
    ROUND(AVG(pr.rating), 2) AS avg_rating
FROM product_review pr
JOIN product p      ON pr.asin = p.asin
JOIN category c     ON p.category_id = c.category_id
WHERE pr.rating IS NOT NULL
  AND pr.rating > 0
GROUP BY c.category_id, c.category_name
HAVING COUNT(*) >= 100
ORDER BY avg_rating DESC, review_cnt DESC
LIMIT 15;
DROP INDEX idx_pr_rating_asin ON product_review;

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 

CREATE INDEX idx_pr_asin_rating ON product_review (asin, rating);
EXPLAIN ANALYZE
SELECT
    c.category_name,
    COUNT(*) AS review_cnt,
    ROUND(AVG(pr.rating), 2) AS avg_rating
FROM product_review pr
JOIN product p      ON pr.asin = p.asin
JOIN category c     ON p.category_id = c.category_id
WHERE pr.rating IS NOT NULL
  AND pr.rating > 0
GROUP BY c.category_id, c.category_name
HAVING COUNT(*) >= 100
ORDER BY avg_rating DESC, review_cnt DESC
LIMIT 15;
DROP INDEX idx_pr_asin_rating ON product_review;

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 

CREATE INDEX idx_p_category ON product (category_id);
EXPLAIN ANALYZE
SELECT
    c.category_name,
    COUNT(*) AS review_cnt,
    ROUND(AVG(pr.rating), 2) AS avg_rating
FROM product_review pr
JOIN product p      ON pr.asin = p.asin
JOIN category c     ON p.category_id = c.category_id
WHERE pr.rating IS NOT NULL
  AND pr.rating > 0
GROUP BY c.category_id, c.category_name
HAVING COUNT(*) >= 100
ORDER BY avg_rating DESC, review_cnt DESC
LIMIT 15;
DROP INDEX idx_p_category ON product;

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 








-- -- Q2: Store performance summary
EXPLAIN ANALYZE
SELECT
    s.store_id,
    COUNT(DISTINCT p.asin) AS product_cnt,
    COUNT(pr.asin) AS total_reviews,
    ROUND(AVG(pr.rating), 2) AS avg_rating,
    COUNT(DISTINCT pr.buyer_id) AS distinct_reviewers
FROM store s
JOIN product p         ON p.store_id = s.store_id
JOIN product_review pr ON pr.asin = p.asin
WHERE pr.rating IS NOT NULL
  AND pr.rating > 0
  AND s.store_id <> 'Unknown Store'
GROUP BY s.store_id
HAVING COUNT(pr.asin) >= 10
ORDER BY avg_rating DESC, total_reviews DESC
LIMIT 15;



-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 


-- -- plan1 :
CREATE INDEX idx_pr_asin_buyer_rating
ON product_review(asin, buyer_id, rating);

EXPLAIN ANALYZE
SELECT
    s.store_id,
    COUNT(DISTINCT p.asin) AS product_cnt,
    COUNT(pr.asin) AS total_reviews,
    ROUND(AVG(pr.rating), 2) AS avg_rating,
    COUNT(DISTINCT pr.buyer_id) AS distinct_reviewers
FROM store s
JOIN product p         ON p.store_id = s.store_id
JOIN product_review pr ON pr.asin = p.asin
WHERE pr.rating IS NOT NULL
  AND pr.rating > 0
GROUP BY s.store_id
HAVING COUNT(pr.asin) >= 10
ORDER BY avg_rating DESC, total_reviews DESC
LIMIT 15;

DROP INDEX idx_pr_asin_buyer_rating ON product_review;


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 


-- -- plan2:
-- CREATE (Strategy B)
CREATE INDEX idx_p_store_asin ON product(store_id, asin);
CREATE INDEX idx_pr_asin      ON product_review(asin);

-- (Optional but recommended) refresh stats
ANALYZE TABLE product, product_review, store;

-- MEASURE
EXPLAIN ANALYZE
SELECT
    s.store_id,
    COUNT(DISTINCT p.asin) AS product_cnt,
    COUNT(pr.asin) AS total_reviews,
    ROUND(AVG(pr.rating), 2) AS avg_rating,
    COUNT(DISTINCT pr.buyer_id) AS distinct_reviewers
FROM store s
JOIN product p         ON p.store_id = s.store_id
JOIN product_review pr ON pr.asin = p.asin
WHERE pr.rating > 0
GROUP BY s.store_id
HAVING COUNT(pr.asin) >= 10
ORDER BY avg_rating DESC, total_reviews DESC
LIMIT 15;

-- DROP (clean up after you record the result)
DROP INDEX idx_pr_asin       ON product_review;
DROP INDEX idx_p_store_asin  ON product;


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 


-- plan 3:
CREATE INDEX idx_pr_asin_buyer_rating ON product_review(asin, buyer_id, rating);
CREATE INDEX idx_p_store_asin         ON product(store_id, asin);

EXPLAIN ANALYZE
SELECT
    s.store_id,
    COUNT(DISTINCT p.asin) AS product_cnt,
    COUNT(pr.asin) AS total_reviews,
    ROUND(AVG(pr.rating), 2) AS avg_rating,
    COUNT(DISTINCT pr.buyer_id) AS distinct_reviewers
FROM store s
JOIN product p         ON p.store_id = s.store_id
JOIN product_review pr ON pr.asin = p.asin
WHERE pr.rating > 0
GROUP BY s.store_id
HAVING COUNT(pr.asin) >= 10
ORDER BY avg_rating DESC, total_reviews DESC
LIMIT 15;

DROP INDEX idx_p_store_asin         ON product;
DROP INDEX idx_pr_asin_buyer_rating ON product_review;


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 


-- plan4:
CREATE INDEX idx_pr_rating_asin_buyer ON product_review(rating, asin, buyer_id);

EXPLAIN ANALYZE
SELECT
    s.store_id,
    COUNT(DISTINCT p.asin) AS product_cnt,
    COUNT(pr.asin) AS total_reviews,
    ROUND(AVG(pr.rating), 2) AS avg_rating,
    COUNT(DISTINCT pr.buyer_id) AS distinct_reviewers
FROM store s
JOIN product p         ON p.store_id = s.store_id
JOIN product_review pr ON pr.asin = p.asin
WHERE pr.rating > 0
GROUP BY s.store_id
HAVING COUNT(pr.asin) >= 10
ORDER BY avg_rating DESC, total_reviews DESC
LIMIT 15;

DROP INDEX idx_pr_rating_asin_buyer ON product_review;


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 









-- -- Q3: Products outperforming their category average
EXPLAIN ANALYZE
WITH pr_valid AS (
  SELECT pr.asin, pr.rating
  FROM product_review pr
  WHERE pr.rating IS NOT NULL AND pr.rating > 0
),
prod_stats AS (
  SELECT p.asin, p.product_name, p.category_id,
         AVG(v.rating) AS product_avg,
         COUNT(*)      AS review_cnt
  FROM product p
  JOIN pr_valid v ON v.asin = p.asin
  GROUP BY p.asin, p.product_name, p.category_id
),
cat_stats AS (
  SELECT p.category_id, AVG(v.rating) AS category_avg
  FROM product p
  JOIN pr_valid v ON v.asin = p.asin
  GROUP BY p.category_id
)
SELECT
  ps.asin,
  ps.product_name,
  c.category_name,
  ROUND(ps.product_avg, 2) AS product_avg,
  ROUND(cs.category_avg, 2) AS category_avg,
  ps.review_cnt
FROM prod_stats ps
JOIN cat_stats cs  USING (category_id)
JOIN category   c  USING (category_id)
WHERE ps.review_cnt >= 10
  AND ps.product_avg > cs.category_avg
ORDER BY product_avg DESC, review_cnt DESC
LIMIT 15;

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 


-- -- Stra1 CREATE
CREATE INDEX idx_pr_asin_rating   ON product_review (asin, rating);
CREATE INDEX idx_p_asin_category  ON product (asin, category_id);
ANALYZE TABLE product_review, product, category;
EXPLAIN ANALYZE
WITH pr_valid AS (
  SELECT pr.asin, pr.rating
  FROM product_review pr
  WHERE pr.rating IS NOT NULL AND pr.rating > 0
),
prod_stats AS (
  SELECT p.asin, p.product_name, p.category_id,
         AVG(v.rating) AS product_avg,
         COUNT(*)      AS review_cnt
  FROM product p
  JOIN pr_valid v ON v.asin = p.asin
  GROUP BY p.asin, p.product_name, p.category_id
),
cat_stats AS (
  SELECT p.category_id, AVG(v.rating) AS category_avg
  FROM product p
  JOIN pr_valid v ON v.asin = p.asin
  GROUP BY p.category_id
)
SELECT
  ps.asin, ps.product_name, c.category_name,
  ROUND(ps.product_avg, 2) AS product_avg,
  ROUND(cs.category_avg, 2) AS category_avg,
  ps.review_cnt
FROM prod_stats ps
JOIN cat_stats cs USING (category_id)
JOIN category c  USING (category_id)
WHERE ps.review_cnt >= 10
  AND ps.product_avg > cs.category_avg
ORDER BY product_avg DESC, review_cnt DESC
LIMIT 15;

DROP INDEX idx_p_asin_category ON product;
DROP INDEX idx_pr_asin_rating  ON product_review;


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 


-- -- Stra2 CREATE
CREATE INDEX idx_p_category_asin ON product (category_id, asin);
CREATE INDEX idx_pr_asin         ON product_review (asin);
ANALYZE TABLE product, product_review, category;
EXPLAIN ANALYZE
WITH pr_valid AS (
  SELECT pr.asin, pr.rating
  FROM product_review pr
  WHERE pr.rating IS NOT NULL AND pr.rating > 0
),
prod_stats AS (
  SELECT p.asin, p.product_name, p.category_id,
         AVG(v.rating) AS product_avg,
         COUNT(*)      AS review_cnt
  FROM product p
  JOIN pr_valid v ON v.asin = p.asin
  GROUP BY p.asin, p.product_name, p.category_id
),
cat_stats AS (
  SELECT p.category_id, AVG(v.rating) AS category_avg
  FROM product p
  JOIN pr_valid v ON v.asin = p.asin
  GROUP BY p.category_id
)
SELECT
  ps.asin, ps.product_name, c.category_name,
  ROUND(ps.product_avg, 2) AS product_avg,
  ROUND(cs.category_avg, 2) AS category_avg,
  ps.review_cnt
FROM prod_stats ps
JOIN cat_stats cs USING (category_id)
JOIN category c  USING (category_id)
WHERE ps.review_cnt >= 10
  AND ps.product_avg > cs.category_avg
ORDER BY product_avg DESC, review_cnt DESC
LIMIT 15;

DROP INDEX idx_pr_asin         ON product_review;
DROP INDEX idx_p_category_asin ON product;


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 



-- -- Stra3 CREATE
CREATE INDEX idx_pr_asin_rating        ON product_review (asin, rating);
CREATE INDEX idx_p_asin_category       ON product (asin, category_id);
CREATE INDEX idx_p_category_asin       ON product (category_id, asin);
ANALYZE TABLE product_review, product, category;
EXPLAIN ANALYZE
WITH pr_valid AS (
  SELECT pr.asin, pr.rating
  FROM product_review pr
  WHERE pr.rating IS NOT NULL AND pr.rating > 0
),
prod_stats AS (
  SELECT p.asin, p.product_name, p.category_id,
         AVG(v.rating) AS product_avg,
         COUNT(*)      AS review_cnt
  FROM product p
  JOIN pr_valid v ON v.asin = p.asin
  GROUP BY p.asin, p.product_name, p.category_id
),
cat_stats AS (
  SELECT p.category_id, AVG(v.rating) AS category_avg
  FROM product p
  JOIN pr_valid v ON v.asin = p.asin
  GROUP BY p.category_id
)
SELECT
  ps.asin, ps.product_name, c.category_name,
  ROUND(ps.product_avg, 2) AS product_avg,
  ROUND(cs.category_avg, 2) AS category_avg,
  ps.review_cnt
FROM prod_stats ps
JOIN cat_stats cs USING (category_id)
JOIN category c  USING (category_id)
WHERE ps.review_cnt >= 10
  AND ps.product_avg > cs.category_avg
ORDER BY product_avg DESC, review_cnt DESC
LIMIT 15;

DROP INDEX idx_p_category_asin       ON product;
DROP INDEX idx_p_asin_category       ON product;
DROP INDEX idx_pr_asin_rating        ON product_review;


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 









-- -- Q4: Loyal buyers per store (purchased AND reviewed in same store)
-- -- Refresh statistics (recommended before measuring)
-- ANALYZE TABLE product_review, buyer_purchase, product, category;

-- -- === BASELINE MEASUREMENT ===
EXPLAIN ANALYZE
WITH purchases AS (
  SELECT p.store_id, bp.buyer_id, COUNT(DISTINCT bp.asin) AS purchased_items
  FROM buyer_purchase bp
  JOIN product p ON p.asin = bp.asin
  WHERE p.store_id <> 'Unknown Store'
  GROUP BY p.store_id, bp.buyer_id
),
reviews AS (
  SELECT p.store_id, pr.buyer_id,
         COUNT(DISTINCT pr.asin) AS reviewed_items,
         ROUND(AVG(pr.rating), 2) AS avg_given_rating
  FROM product_review pr
  JOIN product p ON p.asin = pr.asin
  WHERE pr.rating IS NOT NULL AND pr.rating > 0
    AND p.store_id <> 'Unknown Store'
  GROUP BY p.store_id, pr.buyer_id
)
SELECT
  pu.store_id,
  pu.buyer_id,
  pu.purchased_items,
  rv.reviewed_items,
  rv.avg_given_rating
FROM purchases pu
JOIN reviews rv
  ON rv.store_id = pu.store_id AND rv.buyer_id = pu.buyer_id
WHERE pu.purchased_items >= 1
  AND rv.reviewed_items >= 1
ORDER BY pu.purchased_items DESC, rv.reviewed_items DESC, rv.avg_given_rating DESC
LIMIT 15;


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 


-- -- stra 1
CREATE INDEX idx_pr_asin_buyer_rating ON product_review (asin, buyer_id, rating);
CREATE INDEX idx_p_asin_store         ON product (asin, store_id);
ANALYZE TABLE product_review, product, buyer_purchase;
EXPLAIN ANALYZE
WITH purchases AS (
  SELECT p.store_id, bp.buyer_id, COUNT(DISTINCT bp.asin) AS purchased_items
  FROM buyer_purchase bp
  JOIN product p ON p.asin = bp.asin
  WHERE p.store_id <> 'Unknown Store'
  GROUP BY p.store_id, bp.buyer_id
),
reviews AS (
  SELECT p.store_id, pr.buyer_id,
         COUNT(DISTINCT pr.asin) AS reviewed_items,
         ROUND(AVG(pr.rating), 2) AS avg_given_rating
  FROM product_review pr
  JOIN product p ON p.asin = pr.asin
  WHERE pr.rating IS NOT NULL AND pr.rating > 0
    AND p.store_id <> 'Unknown Store'
  GROUP BY p.store_id, pr.buyer_id
)
SELECT pu.store_id, pu.buyer_id, pu.purchased_items,
       rv.reviewed_items, rv.avg_given_rating
FROM purchases pu
JOIN reviews   rv
  ON rv.store_id = pu.store_id AND rv.buyer_id = pu.buyer_id
WHERE pu.purchased_items >= 1
  AND rv.reviewed_items >= 1
ORDER BY pu.purchased_items DESC, rv.reviewed_items DESC, rv.avg_given_rating DESC
LIMIT 15;

DROP INDEX idx_p_asin_store         ON product;
DROP INDEX idx_pr_asin_buyer_rating ON product_review;


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 


-- -- stra 2
CREATE INDEX idx_p_store_asin ON product (store_id, asin);
CREATE INDEX idx_pr_asin      ON product_review (asin);
CREATE INDEX idx_bp_asin      ON buyer_purchase (asin);
ANALYZE TABLE product, product_review, buyer_purchase;

EXPLAIN ANALYZE
WITH purchases AS (
  SELECT p.store_id, bp.buyer_id, COUNT(DISTINCT bp.asin) AS purchased_items
  FROM buyer_purchase bp
  JOIN product p ON p.asin = bp.asin
  WHERE p.store_id <> 'Unknown Store'
  GROUP BY p.store_id, bp.buyer_id
),
reviews AS (
  SELECT p.store_id, pr.buyer_id,
         COUNT(DISTINCT pr.asin) AS reviewed_items,
         ROUND(AVG(pr.rating), 2) AS avg_given_rating
  FROM product_review pr
  JOIN product p ON p.asin = pr.asin
  WHERE pr.rating IS NOT NULL AND pr.rating > 0
    AND p.store_id <> 'Unknown Store'
  GROUP BY p.store_id, pr.buyer_id
)
SELECT pu.store_id, pu.buyer_id, pu.purchased_items,
       rv.reviewed_items, rv.avg_given_rating
FROM purchases pu
JOIN reviews   rv
  ON rv.store_id = pu.store_id AND rv.buyer_id = pu.buyer_id
WHERE pu.purchased_items >= 1
  AND rv.reviewed_items >= 1
ORDER BY pu.purchased_items DESC, rv.reviewed_items DESC, rv.avg_given_rating DESC
LIMIT 15;

DROP INDEX idx_bp_asin      ON buyer_purchase;
DROP INDEX idx_pr_asin      ON product_review;
DROP INDEX idx_p_store_asin ON product;


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 


-- stra3
CREATE INDEX idx_pr_asin_buyer_rating ON product_review (asin, buyer_id, rating);
CREATE INDEX idx_bp_asin_buyer        ON buyer_purchase (asin, buyer_id);
CREATE INDEX idx_p_store_asin         ON product (store_id, asin);
ANALYZE TABLE product_review, buyer_purchase, product;

EXPLAIN ANALYZE
WITH purchases AS (
  SELECT p.store_id, bp.buyer_id, COUNT(DISTINCT bp.asin) AS purchased_items
  FROM buyer_purchase bp
  JOIN product p ON p.asin = bp.asin
  WHERE p.store_id <> 'Unknown Store'
  GROUP BY p.store_id, bp.buyer_id
),
reviews AS (
  SELECT p.store_id, pr.buyer_id,
         COUNT(DISTINCT pr.asin) AS reviewed_items,
         ROUND(AVG(pr.rating), 2) AS avg_given_rating
  FROM product_review pr
  JOIN product p ON p.asin = pr.asin
  WHERE pr.rating IS NOT NULL AND pr.rating > 0
    AND p.store_id <> 'Unknown Store'
  GROUP BY p.store_id, pr.buyer_id
)
SELECT pu.store_id, pu.buyer_id, pu.purchased_items,
       rv.reviewed_items, rv.avg_given_rating
FROM purchases pu
JOIN reviews   rv
  ON rv.store_id = pu.store_id AND rv.buyer_id = pu.buyer_id
WHERE pu.purchased_items >= 1
  AND rv.reviewed_items >= 1
ORDER BY pu.purchased_items DESC, rv.reviewed_items DESC, rv.avg_given_rating DESC
LIMIT 15;

DROP INDEX idx_p_store_asin         ON product;
DROP INDEX idx_bp_asin_buyer        ON buyer_purchase;
DROP INDEX idx_pr_asin_buyer_rating ON product_review;
