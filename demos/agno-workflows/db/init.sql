-- =============================================================================
-- SwiftGear Demo Database — standalone init for agno-workflows demo
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Schemas
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS sales_transaction_ledger;
CREATE SCHEMA IF NOT EXISTS customer_demographic_master;
CREATE SCHEMA IF NOT EXISTS inventory_snapshot;

-- ---------------------------------------------------------------------------
-- Users
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sales_transaction_ledger_user') THEN
        CREATE USER sales_transaction_ledger_user WITH PASSWORD 'sales_transaction_ledger_pwd';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'customer_demographic_master_user') THEN
        CREATE USER customer_demographic_master_user WITH PASSWORD 'customer_demographic_master_pwd';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'inventory_snapshot_user') THEN
        CREATE USER inventory_snapshot_user WITH PASSWORD 'inventory_snapshot_pwd';
    END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- sales_transaction_ledger tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS sales_transaction_ledger.orders (
    order_id      SERIAL PRIMARY KEY,
    customer_id   INT            NOT NULL,
    total_amount  INT            NOT NULL,  -- cents
    status        VARCHAR(50),
    created_at    TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    shipped_at    TIMESTAMPTZ,
    calculated_total INT                   -- deprecated, do not use
);

CREATE TABLE IF NOT EXISTS sales_transaction_ledger.order_items (
    item_id    SERIAL PRIMARY KEY,
    order_id   INT         NOT NULL REFERENCES sales_transaction_ledger.orders(order_id),
    sku        VARCHAR(50) NOT NULL,
    price_cents INT        NOT NULL,
    quantity   INT         NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sales_transaction_ledger.recurring_revenue (
    subscription_id SERIAL PRIMARY KEY,
    customer_id     INT          NOT NULL,
    mrr             INT          NOT NULL,  -- cents
    status          VARCHAR(50)  NOT NULL,
    started_at      TIMESTAMPTZ  NOT NULL,
    ended_at        TIMESTAMPTZ
);

-- ---------------------------------------------------------------------------
-- customer_demographic_master tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS customer_demographic_master.customers (
    id          SERIAL PRIMARY KEY,
    full_name   VARCHAR(200) NOT NULL,
    email       VARCHAR(200) NOT NULL UNIQUE,
    signup_date DATE         NOT NULL,
    acquired_by INT                      -- internal admin ID, not a customer FK
);

CREATE TABLE IF NOT EXISTS customer_demographic_master.web_sessions (
    session_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         NOT NULL,    -- anonymous, cannot join to customers.id
    page_path  VARCHAR(500) NOT NULL,
    viewed_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- inventory_snapshot tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS inventory_snapshot.inventory_latest (
    sku          VARCHAR(50)  PRIMARY KEY,
    qty_oh       INT          NOT NULL DEFAULT 0,
    warehouse_id VARCHAR(20)  NOT NULL
);

CREATE TABLE IF NOT EXISTS inventory_snapshot.stock_levels (
    id          SERIAL PRIMARY KEY,
    sku         VARCHAR(50)  NOT NULL,
    qty_oh      INT          NOT NULL,
    is_retired  BOOLEAN      NOT NULL DEFAULT FALSE,
    captured_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Seed data — sales_transaction_ledger
-- ---------------------------------------------------------------------------

INSERT INTO sales_transaction_ledger.orders
    (customer_id, total_amount, status, created_at, shipped_at, calculated_total)
VALUES
    (1,  14999, 'SHIPPED',    '2025-01-05 09:12:00+00', '2025-01-07 14:00:00+00', 0),
    (2,   8750, 'SHIPPED',    '2025-01-08 11:30:00+00', '2025-01-10 10:00:00+00', 0),
    (3,  22000, 'SHIPPED',    '2025-01-12 14:00:00+00', '2025-01-15 08:30:00+00', 0),
    (4,   5000, 'PROCESSING', '2025-01-15 08:45:00+00', NULL,                     0),
    (5,  31500, 'SHIPPED',    '2025-01-18 16:20:00+00', '2025-01-21 09:00:00+00', 0),
    (1,  12000, 'SHIPPED',    '2025-02-01 10:00:00+00', '2025-02-03 12:00:00+00', 0),
    (6,   9900, 'CANCELED',   '2025-02-05 15:00:00+00', NULL,                     0),
    (7,  45000, 'SHIPPED',    '2025-02-10 11:00:00+00', '2025-02-13 10:30:00+00', 0),
    (8,   7500, 'SHIPPED',    '2025-02-14 09:00:00+00', '2025-02-16 08:00:00+00', 0),
    (2,  18000, 'PROCESSING', '2025-02-20 13:30:00+00', NULL,                     0),
    (9,  26000, 'SHIPPED',    '2025-03-01 10:15:00+00', '2025-03-04 11:00:00+00', 0),
    (10, 11000, 'SHIPPED',    '2025-03-05 08:00:00+00', '2025-03-07 09:00:00+00', 0),
    (3,   6500, 'CANCELED',   '2025-03-10 14:00:00+00', NULL,                     0),
    (4,  33000, 'SHIPPED',    '2025-03-15 16:00:00+00', '2025-03-18 10:00:00+00', 0),
    (5,  19500, 'SHIPPED',    '2025-03-20 09:45:00+00', '2025-03-22 11:30:00+00', 0)
ON CONFLICT DO NOTHING;

INSERT INTO sales_transaction_ledger.order_items
    (order_id, sku, price_cents, quantity)
VALUES
    (1,  'CAMP-001',  4999, 2),
    (1,  'CAMP-002',  5001, 1),
    (2,  'GEAR-010',  8750, 1),
    (3,  'CAMP-003', 11000, 2),
    (4,  'GEAR-020',  5000, 1),
    (5,  'CAMP-001',  4999, 3),
    (5,  'GEAR-030', 17003, 1),
    (6,  'CAMP-002',  5001, 1),
    (6,  'GEAR-010',  4899, 1),
    (7,  'GEAR-040', 45000, 1),
    (8,  'CAMP-004',  7500, 1),
    (9,  'CAMP-001',  4999, 2),
    (9,  'CAMP-003', 11000, 1),
    (9,  'GEAR-010',  5002, 1),
    (10, 'GEAR-050', 11000, 1),
    (11, 'CAMP-005', 13000, 2),
    (12, 'GEAR-060', 11000, 1),
    (13, 'CAMP-001',  6500, 1),
    (14, 'GEAR-070', 33000, 1),
    (15, 'CAMP-002',  9750, 2)
ON CONFLICT DO NOTHING;

INSERT INTO sales_transaction_ledger.recurring_revenue
    (customer_id, mrr, status, started_at, ended_at)
VALUES
    (1,  9900, 'ACTIVE',   '2024-03-01 00:00:00+00', NULL),
    (2,  9900, 'ACTIVE',   '2024-06-15 00:00:00+00', NULL),
    (3,  2900, 'TRIAL',    '2025-01-01 00:00:00+00', NULL),
    (4,  9900, 'CANCELED', '2023-11-01 00:00:00+00', '2024-11-01 00:00:00+00'),
    (5,  9900, 'ACTIVE',   '2024-08-01 00:00:00+00', NULL),
    (6,  2900, 'CANCELED', '2024-01-15 00:00:00+00', '2024-07-15 00:00:00+00'),
    (7,  9900, 'ACTIVE',   '2024-09-01 00:00:00+00', NULL),
    (8,  2900, 'TRIAL',    '2025-02-01 00:00:00+00', NULL),
    (9,  9900, 'ACTIVE',   '2024-04-01 00:00:00+00', NULL),
    (10, 9900, 'ACTIVE',   '2024-12-01 00:00:00+00', NULL),
    (11, 9900, 'CANCELED', '2024-02-01 00:00:00+00', '2025-02-01 00:00:00+00'),
    (12, 2900, 'TRIAL',    '2025-03-01 00:00:00+00', NULL)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Seed data — customer_demographic_master
-- ---------------------------------------------------------------------------

INSERT INTO customer_demographic_master.customers
    (full_name, email, signup_date, acquired_by)
VALUES
    ('Alice Martin',    'alice.martin@example.com',    '2023-08-15', 101),
    ('Bob Chen',        'bob.chen@example.com',        '2023-10-02', 102),
    ('Carol Davis',     'carol.davis@example.com',     '2024-01-20', 101),
    ('Dan Kowalski',    'dan.kowalski@example.com',    '2024-02-14', 103),
    ('Elena Rossi',     'elena.rossi@example.com',     '2024-03-05', 102),
    ('Frank Nguyen',    'frank.nguyen@example.com',    '2024-04-18', 104),
    ('Grace Okonkwo',   'grace.okonkwo@example.com',   '2024-05-22', 101),
    ('Henry Park',      'henry.park@example.com',      '2024-06-30', 103),
    ('Isabelle Leroy',  'isabelle.leroy@example.com',  '2024-07-11', 102),
    ('James Patel',     'james.patel@example.com',     '2024-08-08', 104),
    ('Karen Svensson',  'karen.svensson@example.com',  '2024-09-15', 101),
    ('Liam O''Brien',   'liam.obrien@example.com',     '2024-10-03', 103)
ON CONFLICT DO NOTHING;

INSERT INTO customer_demographic_master.web_sessions
    (user_id, page_path, viewed_at)
VALUES
    (gen_random_uuid(), '/products/camping', '2025-01-10 08:30:00+00'),
    (gen_random_uuid(), '/products/gear',    '2025-01-10 09:00:00+00'),
    (gen_random_uuid(), '/checkout',         '2025-01-11 11:15:00+00'),
    (gen_random_uuid(), '/products/camping', '2025-01-12 14:00:00+00'),
    (gen_random_uuid(), '/home',             '2025-01-13 10:00:00+00'),
    (gen_random_uuid(), '/products/gear',    '2025-01-14 16:45:00+00'),
    (gen_random_uuid(), '/checkout',         '2025-01-15 08:00:00+00'),
    (gen_random_uuid(), '/products/camping', '2025-02-01 09:30:00+00'),
    (gen_random_uuid(), '/home',             '2025-02-02 12:00:00+00'),
    (gen_random_uuid(), '/products/gear',    '2025-02-03 15:00:00+00'),
    (gen_random_uuid(), '/checkout',         '2025-02-04 10:30:00+00'),
    (gen_random_uuid(), '/products/camping', '2025-02-05 11:00:00+00'),
    (gen_random_uuid(), '/home',             '2025-02-10 09:00:00+00'),
    (gen_random_uuid(), '/products/gear',    '2025-02-15 14:00:00+00'),
    (gen_random_uuid(), '/checkout',         '2025-03-01 11:30:00+00')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Seed data — inventory_snapshot
-- ---------------------------------------------------------------------------

INSERT INTO inventory_snapshot.inventory_latest
    (sku, qty_oh, warehouse_id)
VALUES
    ('CAMP-001', 120, 'WH-EAST'),
    ('CAMP-002',  85, 'WH-EAST'),
    ('CAMP-003',  40, 'WH-WEST'),
    ('CAMP-004',  55, 'WH-EAST'),
    ('CAMP-005',  30, 'WH-WEST'),
    ('GEAR-010', 200, 'WH-EAST'),
    ('GEAR-020', 150, 'WH-WEST'),
    ('GEAR-030',  75, 'WH-EAST'),
    ('GEAR-040',  20, 'WH-WEST'),
    ('GEAR-050',  90, 'WH-EAST'),
    ('GEAR-060',  60, 'WH-WEST'),
    ('GEAR-070',  15, 'WH-EAST')
ON CONFLICT DO NOTHING;

INSERT INTO inventory_snapshot.stock_levels
    (sku, qty_oh, is_retired, captured_at)
VALUES
    ('CAMP-001', 150, FALSE, '2025-01-01 06:00:00+00'),
    ('CAMP-001', 135, FALSE, '2025-02-01 06:00:00+00'),
    ('CAMP-001', 120, FALSE, '2025-03-01 06:00:00+00'),
    ('CAMP-002', 100, FALSE, '2025-01-01 06:00:00+00'),
    ('CAMP-002',  90, FALSE, '2025-02-01 06:00:00+00'),
    ('CAMP-002',  85, FALSE, '2025-03-01 06:00:00+00'),
    ('CAMP-003',  60, FALSE, '2025-01-01 06:00:00+00'),
    ('CAMP-003',  50, FALSE, '2025-02-01 06:00:00+00'),
    ('CAMP-003',  40, FALSE, '2025-03-01 06:00:00+00'),
    ('GEAR-010', 250, FALSE, '2025-01-01 06:00:00+00'),
    ('GEAR-010', 220, FALSE, '2025-02-01 06:00:00+00'),
    ('GEAR-010', 200, FALSE, '2025-03-01 06:00:00+00'),
    ('GEAR-999',  10, TRUE,  '2024-06-01 06:00:00+00'),
    ('GEAR-998',   5, TRUE,  '2024-09-01 06:00:00+00'),
    ('CAMP-099',  25, TRUE,  '2024-12-01 06:00:00+00')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

GRANT USAGE ON SCHEMA sales_transaction_ledger TO sales_transaction_ledger_user;
GRANT SELECT ON ALL TABLES IN SCHEMA sales_transaction_ledger TO sales_transaction_ledger_user;

GRANT USAGE ON SCHEMA customer_demographic_master TO customer_demographic_master_user;
GRANT SELECT ON ALL TABLES IN SCHEMA customer_demographic_master TO customer_demographic_master_user;

-- customer_demographic_master also needs to read sales schema for cross-domain joins
GRANT USAGE ON SCHEMA sales_transaction_ledger TO customer_demographic_master_user;
GRANT SELECT ON ALL TABLES IN SCHEMA sales_transaction_ledger TO customer_demographic_master_user;

GRANT USAGE ON SCHEMA inventory_snapshot TO inventory_snapshot_user;
GRANT SELECT ON ALL TABLES IN SCHEMA inventory_snapshot TO inventory_snapshot_user;
