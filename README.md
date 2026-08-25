# Amazon Product Recommender

A full-stack e-commerce prototype built for a database systems course (CS411).
It lets users search a product catalog, view aggregated ratings, simulate
purchases, and leave reviews, backed by a normalized MySQL database with
stored procedures, transactions, and triggers.

## Architecture

A three-tier design:

- **Database** — MySQL. Normalized schema (products, buyers, reviews, purchases,
  inventory, categories) with primary/foreign keys, `UNIQUE` and `CHECK`
  constraints, plus advanced programs (stored procedure, transaction, trigger).
- **Backend** — FastAPI (Python) on port `8000`. Exposes REST endpoints for
  search, CRUD, purchase, and reviews; talks to MySQL via `mysql-connector`.
- **Frontend** — Express (Node.js) on port `3000`. Serves the UI and proxies
  requests to the backend API.

```
Browser (localhost:3000) → Express frontend → FastAPI backend (localhost:8000) → MySQL
```

## Features

- **Keyword search** with category and minimum-rating filters, using SQL
  aggregation to compute average ratings.
- **CRUD** for products (create, read, update, delete) via a Manager Mode toggle.
- **Purchase simulation** backed by a transaction that safely decrements stock.
- **Review submission** that fires a trigger to track product activity.
- **Top products** ranking via a stored procedure.

## Advanced Database Programs

| Program | Type | Purpose |
|---|---|---|
| `sp_get_top_products_in_category` | Stored procedure | Ranks top-rated products (multi-table joins + `GROUP BY`, `IF` control flow) |
| `sp_purchase_product` | Transaction | Purchases an item under `REPEATABLE READ` isolation with row locking to prevent overselling |
| `trg_after_review_insert` | Trigger | Updates a product's `last_activity` timestamp when a new review is inserted |

The full SQL lives in `stage 3.sql` (schema + ETL) and
`stage4_features.sql` (advanced programs).

## Tech Stack

- MySQL 8
- Python 3, FastAPI, Uvicorn, mysql-connector-python, Pydantic
- Node.js, Express, EJS, Axios

## Getting Started

### Prerequisites

- MySQL 8 (with MySQL Workbench)
- Python 3
- Node.js

### 1. Set up the database

In MySQL Workbench, run the two scripts in order:

1. `stage 3.sql` — creates the `Amazon` database, tables, and loads data.
   (Update the `LOAD DATA LOCAL INFILE` paths to point to your local CSV, and
   make sure `local_infile` is enabled on both server and client.)
2. `stage4_features.sql` — creates the stored procedure, transaction, and trigger.

### 2. Configure the backend

Edit the database credentials in `amazon-prototype/backend/main.py` (`DB_CONFIG`)
to match your local MySQL username, password, and database name.

### 3. Start the backend

```bash
cd amazon-prototype/backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

### 4. Start the frontend

```bash
cd amazon-prototype/frontend
npm install
node server.js
```

### 5. Open the app

Visit [http://localhost:3000](http://localhost:3000).

## Project Structure

```
.
├── stage 3.sql                     # Schema + ETL pipeline
├── stage4_features.sql             # Stored procedure, transaction, trigger
├── amazon-prototype/
│   ├── backend/
│   │   ├── main.py                 # FastAPI app (endpoints)
```

## Notes

- The product dataset (`Video_Games.csv`) is not included in the repository.
- Database credentials should be kept out of version control; configure them
  locally rather than committing them.
