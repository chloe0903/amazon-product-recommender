from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional
import mysql.connector
from pydantic import BaseModel

DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "050419zkx",
    "database": "Amazon",
}

def get_db():
    conn = mysql.connector.connect(**DB_CONFIG)
    try:
        yield conn
    finally:
        conn.close()

class Product(BaseModel):
    asin: str
    name: str
    category: str | None = None
    store_id: str | None = None
    price: float | None = None
    avg_rating: float | None = None

class ProductCreate(BaseModel):
    asin: str
    name: str
    category: str
    store_id: str
    price: float | None = None

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    store_id: Optional[str] = None
    price: Optional[float] = None

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/search", response_model=List[Product])
def search_products(
    q: str = "", 
    category: Optional[str] = None, 
    min_rating: Optional[float] = None, 
    db=Depends(get_db)
):
    cursor = db.cursor()
    
    sql = """
        SELECT p.asin, p.product_name, c.category_name, p.store_id, NULL AS price, AVG(pr.rating) as avg_rating
        FROM product p
        LEFT JOIN category c ON p.category_id = c.category_id
        LEFT JOIN product_review pr ON p.asin = pr.asin
    """
    
    conditions = []
    params = []
    
    if q:
        conditions.append("p.product_name LIKE %s")
        params.append(f"%{q}%")
    
    if category and category != "All Categories":
        conditions.append("c.category_name = %s")
        params.append(category)
        
    where_clause = " WHERE " + " AND ".join(conditions) if conditions else ""
    
    sql += where_clause
    sql += " GROUP BY p.asin, p.product_name, c.category_name, p.store_id"
    
    if min_rating is not None:
        sql += " HAVING avg_rating >= %s"
        params.append(min_rating)
        
    sql += " LIMIT 50"

    cursor.execute(sql, tuple(params))
    rows = cursor.fetchall()
    cursor.close()
    
    return [
        Product(
            asin=r[0], 
            name=r[1], 
            category=r[2], 
            store_id=r[3], 
            price=r[4], 
            avg_rating=float(r[5]) if r[5] is not None else 0.0
        )
        for r in rows
    ]

@app.post("/product", response_model=Product)
def create_product(product: ProductCreate, db=Depends(get_db)):
    cursor = db.cursor()
    try:
        cursor.execute("SELECT category_id FROM category WHERE category_name = %s", (product.category,))
        cat_row = cursor.fetchone()
        if not cat_row:
            cursor.execute("INSERT INTO category (category_name) VALUES (%s)", (product.category,))
            cat_id = cursor.lastrowid
        else:
            cat_id = cat_row[0]
            
        cursor.execute("INSERT IGNORE INTO store (store_id) VALUES (%s)", (product.store_id,))
        
        sql = """
            INSERT INTO product (asin, product_name, store_id, category_id)
            VALUES (%s, %s, %s, %s)
        """
        cursor.execute(sql, (product.asin, product.name, product.store_id, cat_id))
        
        cursor.execute("INSERT IGNORE INTO inventory (asin, quantity) VALUES (%s, 100)", (product.asin,))
        
        db.commit()
        return Product(asin=product.asin, name=product.name, category=product.category, store_id=product.store_id, price=product.price)
    except mysql.connector.Error as err:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(err))
    finally:
        cursor.close()

@app.get("/product/{asin}", response_model=Product)
def get_product(asin: str, db=Depends(get_db)):
    cursor = db.cursor()
    sql = """
        SELECT p.asin, p.product_name, c.category_name, p.store_id, NULL AS price
        FROM product p
        LEFT JOIN category c ON p.category_id = c.category_id
        WHERE p.asin = %s
        LIMIT 1;
    """
    cursor.execute(sql, (asin,))
    row = cursor.fetchone()
    cursor.close()
    if not row:
        raise HTTPException(status_code=404, detail="Product not found")
    return Product(asin=row[0], name=row[1], category=row[2], store_id=row[3], price=row[4])

@app.put("/product/{asin}", response_model=Product)
def update_product(asin: str, product: ProductUpdate, db=Depends(get_db)):
    cursor = db.cursor()
    try:
        updates = []
        params = []
        
        if product.name:
            updates.append("product_name = %s")
            params.append(product.name)
        
        if product.store_id:
            cursor.execute("INSERT IGNORE INTO store (store_id) VALUES (%s)", (product.store_id,))
            updates.append("store_id = %s")
            params.append(product.store_id)
            
        if product.category:
            cursor.execute("SELECT category_id FROM category WHERE category_name = %s", (product.category,))
            cat_row = cursor.fetchone()
            if not cat_row:
                 cursor.execute("INSERT INTO category (category_name) VALUES (%s)", (product.category,))
                 cat_id = cursor.lastrowid
            else:
                 cat_id = cat_row[0]
            updates.append("category_id = %s")
            params.append(cat_id)
            
        if not updates:
            raise HTTPException(status_code=400, detail="No fields to update")
            
        sql = f"UPDATE product SET {', '.join(updates)} WHERE asin = %s"
        params.append(asin)
        
        cursor.execute(sql, tuple(params))
        db.commit()
        
        return get_product(asin, db)
        
    except mysql.connector.Error as err:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(err))
    finally:
        cursor.close()

@app.delete("/product/{asin}")
def delete_product(asin: str, db=Depends(get_db)):
    cursor = db.cursor()
    try:
        cursor.execute("DELETE FROM product WHERE asin = %s", (asin,))
        db.commit()
        return {"message": "Product deleted successfully"}
    except mysql.connector.Error as err:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(err))
    finally:
        cursor.close()

class TopProduct(BaseModel):
    asin: str
    name: str
    category: str
    avg_rating: float
    review_count: int

class PurchaseRequest(BaseModel):
    buyer_id: str
    asin: str

class PurchaseResponse(BaseModel):
    status: str

# ----- Advanced Features Endpoints -----

@app.post("/purchase", response_model=PurchaseResponse)
def purchase_product(req: PurchaseRequest, db=Depends(get_db)):
    cursor = db.cursor()
    try:
        cursor.execute("INSERT IGNORE INTO buyer (buyer_id) VALUES (%s)", (req.buyer_id,))

        cursor.execute("INSERT IGNORE INTO inventory (asin, quantity) VALUES (%s, 100)", (req.asin,))
        db.commit()

        cursor.execute("START TRANSACTION")
        cursor.execute("SELECT quantity FROM inventory WHERE asin = %s FOR UPDATE", (req.asin,))
        row = cursor.fetchone()

        current_stock = row[0] if row else 0
        if current_stock is None or current_stock <= 0:
            db.rollback()
            raise HTTPException(status_code=400, detail="FAIL: Out of Stock")

        cursor.execute(
            "UPDATE inventory SET quantity = quantity - 1 WHERE asin = %s AND quantity > 0",
            (req.asin,)
        )
        if cursor.rowcount == 0:
            db.rollback()
            raise HTTPException(status_code=400, detail="FAIL: Out of Stock")

        cursor.execute(
            "INSERT INTO buyer_purchase (buyer_id, asin, purchased_at) VALUES (%s, %s, NOW())",
            (req.buyer_id, req.asin)
        )

        db.commit()
        return PurchaseResponse(status="SUCCESS: Purchased")
    except mysql.connector.Error as err:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()

@app.get("/top-products", response_model=List[TopProduct])
def get_top_products(category: str = "All Categories", db=Depends(get_db)):
    cursor = db.cursor()
    try:
        cursor.callproc('sp_get_top_products_in_category', [category])
        # Fetch results from stored procedure
        for result in cursor.stored_results():
            rows = result.fetchall()
            return [
                TopProduct(asin=r[0], name=r[1], category=r[2], avg_rating=float(r[3]), review_count=r[4])
                for r in rows
            ]
        return []
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()

class ReviewCreate(BaseModel):
    asin: str
    buyer_id: str
    rating: float
    content: str

@app.get("/purchased-products/{buyer_id}", response_model=List[Product])
def get_purchased_products(buyer_id: str, db=Depends(get_db)):
    cursor = db.cursor()
    sql = """
        SELECT DISTINCT p.asin, p.product_name, c.category_name, p.store_id, NULL AS price, AVG(pr.rating) as avg_rating
        FROM buyer_purchase bp
        JOIN product p ON bp.asin = p.asin
        LEFT JOIN category c ON p.category_id = c.category_id
        LEFT JOIN product_review pr ON p.asin = pr.asin
        WHERE bp.buyer_id = %s
        GROUP BY p.asin, p.product_name, c.category_name, p.store_id
    """
    cursor.execute(sql, (buyer_id,))
    rows = cursor.fetchall()
    cursor.close()
    return [
        Product(
            asin=r[0], 
            name=r[1], 
            category=r[2], 
            store_id=r[3], 
            price=r[4], 
            avg_rating=float(r[5]) if r[5] is not None else 0.0
        )
        for r in rows
    ]

@app.post("/review", response_model=dict)
def create_review(review: ReviewCreate, db=Depends(get_db)):
    cursor = db.cursor()
    try:
        cursor.execute("SELECT 1 FROM buyer_purchase WHERE buyer_id = %s AND asin = %s", (review.buyer_id, review.asin))
        if not cursor.fetchone():
             pass

        sql = """
            INSERT INTO product_review (asin, buyer_id, timestamp, content, rating)
            VALUES (%s, %s, NOW(), %s, %s)
            ON DUPLICATE KEY UPDATE content = VALUES(content), rating = VALUES(rating), timestamp = NOW()
        """
        cursor.execute(sql, (review.asin, review.buyer_id, review.content, review.rating))
        db.commit()
        return {"message": "Review submitted successfully"}
    except mysql.connector.Error as err:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(err))
    finally:
        cursor.close()
