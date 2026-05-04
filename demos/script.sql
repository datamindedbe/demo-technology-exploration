-- ============================================================
-- Coffee Shop Chain Demo - Snowflake Intelligence TechEx
-- ============================================================

-- Setup
CREATE DATABASE IF NOT EXISTS COFFEE_DEMO;
USE DATABASE COFFEE_DEMO;
CREATE SCHEMA IF NOT EXISTS ANALYTICS;
USE SCHEMA ANALYTICS;

-- ============================================================
-- STORES
-- ============================================================
CREATE OR REPLACE TABLE stores (
    store_id        INT          COMMENT 'Unique identifier for each store location',
    store_name      VARCHAR(100) COMMENT 'Friendly name of the store',
    city            VARCHAR(50)  COMMENT 'City where the store is located',
    region          VARCHAR(50)  COMMENT 'Geographic region: Flanders, Wallonia, or Brussels',
    manager_name    VARCHAR(100) COMMENT 'Full name of the current store manager',
    opened_date     DATE         COMMENT 'Date when the store first opened',
    seating_capacity INT         COMMENT 'Number of seats available for dine-in customers'
)
COMMENT = 'Store locations for the Bean & Brew coffee shop chain across Belgium';

INSERT INTO stores VALUES
(1,  'Bean & Brew Ghent Center',     'Ghent',       'Flanders',  'Sophie De Vos',      '2019-03-15', 45),
(2,  'Bean & Brew Antwerp Station',  'Antwerp',     'Flanders',  'Thomas Janssen',     '2019-06-01', 60),
(3,  'Bean & Brew Brussels Midi',    'Brussels',    'Brussels',  'Amira El Fassi',     '2020-01-10', 55),
(4,  'Bean & Brew Leuven',           'Leuven',      'Flanders',  'Pieter Claes',       '2020-09-20', 35),
(5,  'Bean & Brew Liège',            'Liège',       'Wallonia',  'Marie Lambert',      '2021-04-05', 40),
(6,  'Bean & Brew Bruges',           'Bruges',      'Flanders',  'Jan Vermeersch',     '2021-11-12', 50),
(7,  'Bean & Brew Namur',            'Namur',       'Wallonia',  'Claire Dubois',      '2022-06-18', 30),
(8,  'Bean & Brew Brussels Louise',  'Brussels',    'Brussels',  'Youssef Benali',     '2023-02-01', 65),
(9,  'Bean & Brew Mechelen',         'Mechelen',    'Flanders',  'Lisa Peeters',       '2024-01-15', 40),
(10, 'Bean & Brew Mons',             'Mons',        'Wallonia',  'Antoine Martin',     '2024-09-01', 35);

-- ============================================================
-- ORDERS
-- ============================================================
CREATE OR REPLACE TABLE orders (
    order_id        INT          COMMENT 'Unique identifier for each order',
    store_id        INT          COMMENT 'Foreign key to the store where the order was placed',
    order_date      DATE         COMMENT 'Date the order was placed',
    order_time      TIME         COMMENT 'Time of day the order was placed',
    customer_type   VARCHAR(20)  COMMENT 'Customer segment: Walk-in, Regular, or Loyalty',
    total_amount    DECIMAL(8,2) COMMENT 'Total order amount in EUR including VAT',
    payment_method  VARCHAR(20)  COMMENT 'How the customer paid: Card, Cash, Mobile, or Meal Voucher'
)
COMMENT = 'Individual customer orders across all Beam & Brew stores';

-- ============================================================
-- ORDER_ITEMS
-- ============================================================
CREATE OR REPLACE TABLE order_items (
    item_id          INT          COMMENT 'Unique identifier for each line item',
    order_id         INT          COMMENT 'Foreign key to the parent order',
    product_name     VARCHAR(100) COMMENT 'Name of the product ordered',
    product_category VARCHAR(50)  COMMENT 'Product grouping: Coffee, Tea, Pastry, Sandwich, Cold Drink, or Merchandise',
    size             VARCHAR(10)  COMMENT 'Drink/item size: S, M, L, or N/A for non-sized items',
    quantity         INT          COMMENT 'Number of this item in the order',
    unit_price       DECIMAL(6,2) COMMENT 'Price per unit in EUR including VAT'
)
COMMENT = 'Individual line items within each order, representing products purchased';

-- ============================================================
-- GENERATE REALISTIC ORDER DATA
-- Using a procedural approach with Snowflake scripting
-- ============================================================

-- Product catalog (used by the generator)
CREATE OR REPLACE TEMPORARY TABLE product_catalog (
    product_name     VARCHAR(100),
    product_category VARCHAR(50),
    size             VARCHAR(10),
    unit_price       DECIMAL(6,2),
    popularity_weight INT -- higher = more likely to be ordered
) AS
SELECT * FROM VALUES
-- Coffee
('Espresso',              'Coffee',     'S',   2.50,  15),
('Espresso',              'Coffee',     'M',   2.90,  8),
('Americano',             'Coffee',     'M',   3.20,  12),
('Americano',             'Coffee',     'L',   3.70,  10),
('Flat White',            'Coffee',     'M',   3.80,  18),
('Flat White',            'Coffee',     'L',   4.30,  12),
('Cappuccino',            'Coffee',     'M',   3.50,  20),
('Cappuccino',            'Coffee',     'L',   4.00,  14),
('Latte',                 'Coffee',     'M',   3.60,  16),
('Latte',                 'Coffee',     'L',   4.10,  11),
('Oat Milk Latte',        'Coffee',     'M',   4.20,  14),
('Oat Milk Latte',        'Coffee',     'L',   4.70,  10),
('Mocha',                 'Coffee',     'M',   4.40,  8),
('Mocha',                 'Coffee',     'L',   4.90,  6),
('Cold Brew',             'Coffee',     'M',   3.90,  7),
('Cold Brew',             'Coffee',     'L',   4.40,  5),
('Iced Latte',            'Coffee',     'M',   4.00,  6),
('Iced Latte',            'Coffee',     'L',   4.50,  4),
-- Tea
('English Breakfast Tea', 'Tea',        'M',   2.80,  8),
('Green Tea',             'Tea',        'M',   2.80,  6),
('Chai Latte',            'Tea',        'M',   4.00,  9),
('Chai Latte',            'Tea',        'L',   4.50,  5),
('Matcha Latte',          'Tea',        'M',   4.50,  7),
('Matcha Latte',          'Tea',        'L',   5.00,  4),
-- Pastry
('Croissant',             'Pastry',     'N/A', 2.80,  22),
('Pain au Chocolat',      'Pastry',     'N/A', 3.20,  16),
('Cinnamon Roll',         'Pastry',     'N/A', 3.50,  12),
('Blueberry Muffin',      'Pastry',     'N/A', 3.30,  10),
('Banana Bread',          'Pastry',     'N/A', 3.40,  9),
('Cookie',                'Pastry',     'N/A', 2.20,  11),
-- Sandwich
('Avocado Toast',         'Sandwich',   'N/A', 6.50,  8),
('Ham & Cheese Panini',   'Sandwich',   'N/A', 6.80,  10),
('Veggie Wrap',           'Sandwich',   'N/A', 6.20,  6),
('Croque Monsieur',       'Sandwich',   'N/A', 7.00,  9),
-- Cold Drink
('Fresh Orange Juice',    'Cold Drink', 'M',   4.20,  7),
('Fresh Orange Juice',    'Cold Drink', 'L',   5.00,  4),
('Sparkling Water',       'Cold Drink', 'N/A', 2.50,  5),
('Homemade Lemonade',     'Cold Drink', 'M',   3.80,  5),
('Homemade Lemonade',     'Cold Drink', 'L',   4.30,  3),
-- Merchandise
('Branded Mug',           'Merchandise','N/A', 14.90, 1),
('Coffee Beans 250g',     'Merchandise','N/A', 12.50, 2),
('Reusable Cup',          'Merchandise','N/A', 9.90,  1)
;

-- Generate orders and items using a stored procedure
CREATE OR REPLACE PROCEDURE generate_sample_data(num_orders FLOAT)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    // Date range: 2024-07-01 to 2026-03-31
    var startDate = new Date(2024, 6, 1);  // July 2024
    var endDate   = new Date(2026, 2, 31); // March 2026
    var totalDays = Math.floor((endDate - startDate) / (1000*60*60*24));

    var orderBatch = [];
    var itemBatch  = [];
    var itemId = 1;

    // Customer types with weights
    var customerTypes = [
        {type: 'Walk-in',  weight: 40},
        {type: 'Regular',  weight: 35},
        {type: 'Loyalty',  weight: 25}
    ];

    // Payment methods with weights
    var paymentMethods = [
        {method: 'Card',         weight: 45},
        {method: 'Mobile',       weight: 25},
        {method: 'Cash',         weight: 20},
        {method: 'Meal Voucher', weight: 10}
    ];

    function weightedRandom(items, weightKey, valueKey) {
        var totalWeight = items.reduce(function(sum, i) { return sum + i[weightKey]; }, 0);
        var r = Math.random() * totalWeight;
        var cumulative = 0;
        for (var i = 0; i < items.length; i++) {
            cumulative += items[i][weightKey];
            if (r <= cumulative) return items[i][valueKey];
        }
        return items[items.length - 1][valueKey];
    }

    // Get product catalog
    var stmt = snowflake.createStatement({sqlText: "SELECT product_name, product_category, size, unit_price, popularity_weight FROM product_catalog"});
    var rs = stmt.execute();
    var products = [];
    while (rs.next()) {
        products.push({
            name: rs.getColumnValue(1),
            category: rs.getColumnValue(2),
            size: rs.getColumnValue(3),
            price: parseFloat(rs.getColumnValue(4)),
            weight: parseInt(rs.getColumnValue(5)),
            valueKey: products.length
        });
    }

    // Store configs: store_id -> avg daily orders (weekday), with seasonal + growth factors
    var storeBaseOrders = {
        1: 85,   // Ghent - established
        2: 110,  // Antwerp Station - high traffic
        3: 95,   // Brussels Midi - station
        4: 55,   // Leuven - university town
        5: 50,   // Liège
        6: 70,   // Bruges - tourist
        7: 35,   // Namur - smaller
        8: 100,  // Brussels Louise - upscale
        9: 45,   // Mechelen - newer
        10: 30   // Mons - newest
    };

    for (var orderId = 1; orderId <= NUM_ORDERS; orderId++) {
        // Pick a random day
        var dayOffset = Math.floor(Math.random() * totalDays);
        var orderDate = new Date(startDate.getTime() + dayOffset * 24*60*60*1000);
        var month = orderDate.getMonth(); // 0-11
        var dayOfWeek = orderDate.getDay(); // 0=Sun

        // Pick store weighted by base orders
        var storeEntries = [];
        for (var sid in storeBaseOrders) {
            storeEntries.push({storeId: parseInt(sid), weight: storeBaseOrders[sid], valueKey: parseInt(sid)});
        }
        var totalStoreWeight = storeEntries.reduce(function(s,e){return s+e.weight;},0);
        var sr = Math.random() * totalStoreWeight;
        var sc = 0;
        var storeId = 1;
        for (var si = 0; si < storeEntries.length; si++) {
            sc += storeEntries[si].weight;
            if (sr <= sc) { storeId = storeEntries[si].storeId; break; }
        }

        // Generate time of day (peak hours: 7-9, 12-14)
        var hourWeights = [0,0,0,0,0,0,1,8,12,6,4,5,10,8,4,5,6,4,3,2,1,0,0,0];
        var totalHW = hourWeights.reduce(function(a,b){return a+b;},0);
        var hr = Math.random() * totalHW;
        var hc = 0;
        var hour = 7;
        for (var h = 0; h < 24; h++) {
            hc += hourWeights[h];
            if (hr <= hc) { hour = h; break; }
        }
        var minute = Math.floor(Math.random() * 60);
        var second = Math.floor(Math.random() * 60);
        var timeStr = (hour < 10 ? '0' : '') + hour + ':' + (minute < 10 ? '0' : '') + minute + ':' + (second < 10 ? '0' : '') + second;

        // Customer type
        var custType = weightedRandom(customerTypes, 'weight', 'type');

        // Payment method - Loyalty customers prefer Mobile
        var pmWeights = paymentMethods.slice();
        if (custType === 'Loyalty') {
            pmWeights = [
                {method: 'Card', weight: 25},
                {method: 'Mobile', weight: 50},
                {method: 'Cash', weight: 10},
                {method: 'Meal Voucher', weight: 15}
            ];
        }
        var payMethod = weightedRandom(pmWeights, 'weight', 'method');

        // Number of items per order (1-5, weighted toward 2-3)
        var numItemsWeights = [{n:1, w:20}, {n:2, w:35}, {n:3, w:25}, {n:4, w:13}, {n:5, w:7}];
        var numItems = weightedRandom(numItemsWeights, 'w', 'n');

        var totalAmount = 0;
        var orderItems = [];

        // Cold drinks and iced coffee more popular in summer
        for (var ii = 0; ii < numItems; ii++) {
            // Adjust weights by season
            var adjustedProducts = products.map(function(p) {
                var w = p.weight;
                // Summer boost for cold drinks and iced items (June-Aug)
                if ((month >= 5 && month <= 7) && (p.category === 'Cold Drink' || p.name.indexOf('Iced') >= 0 || p.name === 'Cold Brew')) {
                    w = Math.round(w * 2.5);
                }
                // Winter boost for hot chocolate-y things and chai (Nov-Feb)
                if ((month >= 10 || month <= 1) && (p.name === 'Mocha' || p.name === 'Chai Latte')) {
                    w = Math.round(w * 2);
                }
                // Morning boost for pastries (before 10)
                if (hour < 10 && p.category === 'Pastry') {
                    w = Math.round(w * 1.8);
                }
                // Lunch boost for sandwiches (11-14)
                if (hour >= 11 && hour <= 14 && p.category === 'Sandwich') {
                    w = Math.round(w * 3);
                }
                // Oat milk trend: growing over time
                if (p.name.indexOf('Oat') >= 0) {
                    var monthsIn = (orderDate.getFullYear() - 2024) * 12 + orderDate.getMonth() - 6;
                    w = Math.round(w * (1 + monthsIn * 0.04));
                }
                // Matcha trend: growing
                if (p.name.indexOf('Matcha') >= 0) {
                    var monthsIn2 = (orderDate.getFullYear() - 2024) * 12 + orderDate.getMonth() - 6;
                    w = Math.round(w * (1 + monthsIn2 * 0.06));
                }
                return {name: p.name, category: p.category, size: p.size, price: p.price, weight: w};
            });

            var totalPW = adjustedProducts.reduce(function(s,p){return s+p.weight;},0);
            var pr = Math.random() * totalPW;
            var pc = 0;
            var chosenProduct = adjustedProducts[0];
            for (var pi = 0; pi < adjustedProducts.length; pi++) {
                pc += adjustedProducts[pi].weight;
                if (pr <= pc) { chosenProduct = adjustedProducts[pi]; break; }
            }

            var qty = 1;
            // Occasionally someone orders 2 of same item
            if (Math.random() < 0.08) qty = 2;

            totalAmount += chosenProduct.price * qty;

            itemBatch.push("(" + itemId + "," + orderId + ",'" +
                chosenProduct.name.replace(/'/g, "''") + "','" +
                chosenProduct.category + "','" +
                chosenProduct.size + "'," +
                qty + "," + chosenProduct.price.toFixed(2) + ")");
            itemId++;
        }

        // Round total
        totalAmount = Math.round(totalAmount * 100) / 100;

        var dateStr = orderDate.getFullYear() + '-' +
            (month + 1 < 10 ? '0' : '') + (month + 1) + '-' +
            (orderDate.getDate() < 10 ? '0' : '') + orderDate.getDate();

        orderBatch.push("(" + orderId + "," + storeId + ",'" + dateStr + "','" + timeStr + "','" +
            custType + "'," + totalAmount.toFixed(2) + ",'" + payMethod + "')");

        // Insert in batches of 500
        if (orderBatch.length >= 500 || orderId === NUM_ORDERS) {
            var sql1 = "INSERT INTO orders VALUES " + orderBatch.join(",");
            snowflake.createStatement({sqlText: sql1}).execute();
            orderBatch = [];

            var sql2 = "INSERT INTO order_items VALUES " + itemBatch.join(",");
            snowflake.createStatement({sqlText: sql2}).execute();
            itemBatch = [];
        }
    }

    return 'Generated ' + NUM_ORDERS + ' orders with ' + (itemId - 1) + ' line items';
$$;

-- Clear existing data
TRUNCATE TABLE orders;
TRUNCATE TABLE order_items;

-- Generate 15,000 orders (~24 per day across 10 stores over 21 months)
CALL generate_sample_data(15000);

-- ============================================================
-- VERIFY
-- ============================================================
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'stores', COUNT(*) FROM stores;

-- Quick sanity checks
SELECT region, COUNT(*) AS orders, SUM(total_amount) AS revenue
FROM orders o JOIN stores s ON o.store_id = s.store_id
GROUP BY region ORDER BY revenue DESC;

SELECT product_category, COUNT(*) AS items_sold, SUM(unit_price * quantity) AS revenue
FROM order_items
GROUP BY product_category ORDER BY revenue DESC;

SELECT DATE_TRUNC('month', order_date) AS month, COUNT(*) AS orders
FROM orders
GROUP BY month ORDER BY month;

-- ============================================================
-- SEMANTIC VIEW
-- ============================================================
CREATE OR REPLACE SEMANTIC VIEW COFFEE_DEMO.ANALYTICS.coffee_shop_analysis

  TABLES (
    stores AS COFFEE_DEMO.ANALYTICS.STORES
      PRIMARY KEY (store_id)
      WITH SYNONYMS = ('store locations', 'shops')
      COMMENT = 'Store locations for the Bean & Brew coffee shop chain across Belgium',
    orders AS COFFEE_DEMO.ANALYTICS.ORDERS
      PRIMARY KEY (order_id)
      WITH SYNONYMS = ('sales orders', 'transactions')
      COMMENT = 'Individual customer orders across all Bean & Brew stores',
    order_items AS COFFEE_DEMO.ANALYTICS.ORDER_ITEMS
      PRIMARY KEY (item_id)
      WITH SYNONYMS = ('line items', 'products ordered')
      COMMENT = 'Individual line items within each order'
  )

  RELATIONSHIPS (
    orders_to_stores AS
      orders (store_id) REFERENCES stores,
    items_to_orders AS
      order_items (order_id) REFERENCES orders
  )

  FACTS (
    order_items.line_item_revenue AS unit_price * quantity
      COMMENT = 'Revenue for a single line item (unit_price * quantity)',
    order_items.line_item_id AS item_id
      COMMENT = 'Line item identifier used for counting',
    orders.order_item_count AS COUNT(order_items.line_item_id)
      COMMENT = 'Number of line items in an order'
  )

  DIMENSIONS (
    stores.store_name AS store_name
      WITH SYNONYMS = ('shop name')
      COMMENT = 'Friendly name of the store',
    stores.city AS city
      COMMENT = 'City where the store is located',
    stores.region AS region
      WITH SYNONYMS = ('geographic region', 'area')
      COMMENT = 'Geographic region: Flanders, Wallonia, or Brussels',
    stores.manager_name AS manager_name
      COMMENT = 'Full name of the current store manager',
    stores.opened_date AS opened_date
      COMMENT = 'Date when the store first opened',
    stores.seating_capacity AS seating_capacity
      COMMENT = 'Number of seats available for dine-in customers',
    orders.order_date AS order_date
      COMMENT = 'Date the order was placed',
    orders.order_month AS DATE_TRUNC('month', order_date)
      WITH SYNONYMS = ('month')
      COMMENT = 'Month when the order was placed',
    orders.order_year AS YEAR(order_date)
      WITH SYNONYMS = ('year')
      COMMENT = 'Year when the order was placed',
    orders.order_time AS order_time
      COMMENT = 'Time of day the order was placed',
    orders.customer_type AS customer_type
      WITH SYNONYMS = ('customer segment', 'loyalty status')
      COMMENT = 'Customer segment: Walk-in, Regular, or Loyalty',
    orders.payment_method AS payment_method
      WITH SYNONYMS = ('payment type')
      COMMENT = 'How the customer paid: Card, Cash, Mobile, or Meal Voucher',
    order_items.product_name AS product_name
      WITH SYNONYMS = ('item name', 'product')
      COMMENT = 'Name of the product ordered',
    order_items.product_category AS product_category
      WITH SYNONYMS = ('category', 'product type')
      COMMENT = 'Product grouping: Coffee, Tea, Pastry, Sandwich, Cold Drink, or Merchandise',
    order_items.size AS size
      WITH SYNONYMS = ('drink size', 'item size')
      COMMENT = 'Drink/item size: S, M, L, or N/A for non-sized items'
  )

  METRICS (
    orders.total_orders AS COUNT(order_id)
      WITH SYNONYMS = ('number of orders', 'order count')
      COMMENT = 'Total number of orders',
    orders.total_revenue AS SUM(total_amount)
      WITH SYNONYMS = ('revenue', 'sales', 'total sales')
      COMMENT = 'Total revenue in EUR including VAT',
    orders.average_order_value AS AVG(total_amount)
      WITH SYNONYMS = ('AOV', 'avg order value')
      COMMENT = 'Average order value in EUR',
    orders.average_items_per_order AS AVG(orders.order_item_count)
      COMMENT = 'Average number of line items per order',
    order_items.total_items_sold AS SUM(quantity)
      WITH SYNONYMS = ('units sold', 'quantity sold')
      COMMENT = 'Total number of product units sold',
    order_items.item_revenue AS SUM(order_items.line_item_revenue)
      WITH SYNONYMS = ('product revenue', 'item sales')
      COMMENT = 'Total revenue from line items (sum of unit_price * quantity)',
    order_items.average_unit_price AS AVG(unit_price)
      COMMENT = 'Average unit price across items sold',
    stores.store_count AS COUNT(store_id)
      COMMENT = 'Number of stores'
  )

  COMMENT = 'Semantic view for Bean & Brew coffee shop chain analytics across stores, orders, and products';

-- ============================================================
-- STEP 1: Enable Cross-Region Inference. Possible to set EU only
-- ============================================================
USE ROLE ACCOUNTADMIN;

ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'AWS_EU';

-- ============================================================
-- STEP 2: Create a Cortex Search Service (optional, for unstructured data)
-- ============================================================
-- If you have unstructured data (e.g. support tickets, reviews)
-- you can add a Cortex Search tool to the agent.
-- For this demo we'll create a simple knowledge base table
-- and a search service on it.

CREATE OR REPLACE TABLE COFFEE_DEMO.ANALYTICS.COFFEE_KNOWLEDGE_BASE (
    article_id INT,
    title VARCHAR,
    content VARCHAR,
    category VARCHAR
);

INSERT INTO COFFEE_DEMO.ANALYTICS.COFFEE_KNOWLEDGE_BASE VALUES
    (1, 'Store Opening Hours Policy',
     'All Bean & Brew stores operate Monday to Friday 7AM-7PM and Saturday-Sunday 8AM-5PM. Holiday hours may vary and are communicated two weeks in advance by regional managers.',
     'Operations'),
    (2, 'Loyalty Program Rules',
     'Customers earn 1 point per EUR spent. 100 points can be redeemed for a free drink of any size. Points expire after 12 months of inactivity. Loyalty members receive a 10% birthday discount.',
     'Marketing'),
    (3, 'Coffee Sourcing Standards',
     'Bean & Brew sources 100% Arabica beans from certified Fair Trade farms in Colombia, Ethiopia, and Guatemala. All beans are roasted in-house at our Brussels roastery within 2 weeks of delivery.',
     'Product'),
    (4, 'Meal Voucher Acceptance Policy',
     'All Belgian meal vouchers (Edenred, Sodexo, Monizze) are accepted for food and non-alcoholic beverages. Meal vouchers cannot be used for merchandise. No change is given on meal voucher payments.',
     'Finance'),
    (5, 'Barista Training Program',
     'New baristas complete a 2-week training program covering espresso extraction, milk steaming, latte art, and customer service. Quarterly skill assessments ensure quality standards are maintained.',
     'HR');

CREATE OR REPLACE CORTEX SEARCH SERVICE COFFEE_DEMO.ANALYTICS.COFFEE_KNOWLEDGE_SEARCH
    ON content
    ATTRIBUTES category
    WAREHOUSE = COMPUTE_WH
    TARGET_LAG = '1 hour'
AS (
    SELECT
        article_id,
        title,
        content,
        category
    FROM COFFEE_DEMO.ANALYTICS.COFFEE_KNOWLEDGE_BASE
);

-- ============================================================
-- STEP 3: Create the Cortex Agent
-- ============================================================
-- Best practices applied:
--   - Narrowly scoped to one domain (coffee shop analytics)
--   - Model set to "auto" for best quality
--   - Clear, purpose-driven tool descriptions
--   - Specific orchestration instructions
--   - data_to_chart tool enabled for visualizations
--   - Sample questions to guide users

CREATE OR REPLACE AGENT COFFEE_DEMO.ANALYTICS.BEAN_AND_BREW_AGENT
    COMMENT = 'Agent for Bean & Brew coffee shop chain analytics and knowledge base'
    PROFILE = '{"display_name": "Bean & Brew Assistant", "color": "brown"}'
    FROM SPECIFICATION
    $$
    models:
      orchestration: auto

    orchestration:
      budget:
        seconds: 60
        tokens: 16000

    instructions:
      system: >
        You are the Bean & Brew Assistant, an AI analyst for the Bean & Brew
        coffee shop chain in Belgium. You help managers and staff understand
        store performance, sales trends, product popularity, and operational
        policies. Always be concise and actionable.
      orchestration: >
        For questions about sales, revenue, orders, products, stores, or any
        quantitative data, use the Analyst tool. For questions about policies,
        procedures, training, or operational knowledge, use the Search tool.
        When showing trends or comparisons, always generate a chart.
      response: >
        Respond in a friendly, professional tone. Use EUR for currency.
        When presenting numbers, round to 2 decimal places.
        If the user asks in Dutch or French, respond in that language.
      sample_questions:
        - question: "What was our total revenue last month?"
          answer: "I'll query the sales data to find last month's total revenue across all stores."
        - question: "Which product category sells the most?"
          answer: "Let me analyze order items to find the top-selling product category."
        - question: "What is our loyalty program policy?"
          answer: "I'll search our knowledge base for loyalty program details."
        - question: "Show me revenue by region over time"
          answer: "I'll create a chart showing the revenue trend broken down by region."

    tools:
      - tool_spec:
          type: "cortex_analyst_text_to_sql"
          name: "coffee_shop_analyst"
          description: >
            Use this tool for ALL questions about Bean & Brew sales data,
            revenue, orders, products, stores, customers, and any quantitative
            business metrics. This tool accesses structured data about:
            - Store information (names, cities, regions, managers, seating capacity)
            - Order data (dates, times, amounts, customer types, payment methods)
            - Product details (names, categories, sizes, prices, quantities)
            Do NOT use this tool for policy questions, training procedures,
            or operational guidelines.
      - tool_spec:
          type: "cortex_search"
          name: "coffee_knowledge_search"
          description: >
            Use this tool for questions about Bean & Brew policies, procedures,
            operational guidelines, training programs, sourcing standards,
            and any qualitative business knowledge. This covers topics like:
            opening hours, loyalty programs, meal voucher rules, barista training,
            and coffee sourcing. Do NOT use this tool for quantitative data or
            sales analytics.
      - tool_spec:
          type: "data_to_chart"
          name: "data_to_chart"
          description: "Generates visualizations from data. Use whenever showing trends, comparisons, or distributions."

    tool_resources:
      coffee_shop_analyst:
        semantic_view: "COFFEE_DEMO.ANALYTICS.COFFEE_SHOP_ANALYSIS"
      coffee_knowledge_search:
        name: "COFFEE_DEMO.ANALYTICS.COFFEE_KNOWLEDGE_SEARCH"
        max_results: "3"
        title_column: "title"
        id_column: "article_id"
    $$;

-- ============================================================
-- STEP 4: Create the Snowflake Intelligence Object
-- ============================================================
-- This is the account-level object that manages which agents
-- are visible in the Snowflake Intelligence UI.

CREATE OR REPLACE SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- ============================================================
-- STEP 5: Add the Agent to Snowflake Intelligence
-- ============================================================

ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
    ADD AGENT COFFEE_DEMO.ANALYTICS.BEAN_AND_BREW_AGENT;

-- ============================================================
-- STEP 6: Grant Access
-- ============================================================
-- Grant usage on the Snowflake Intelligence object to PUBLIC
-- so all users can see it (adjust role as needed for your org).

GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE PUBLIC;

-- Grant the necessary privileges on the agent itself
GRANT USAGE ON DATABASE COFFEE_DEMO TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA COFFEE_DEMO.ANALYTICS TO ROLE PUBLIC;
GRANT USAGE ON AGENT COFFEE_DEMO.ANALYTICS.BEAN_AND_BREW_AGENT TO ROLE PUBLIC;

-- Grant access to the semantic view and search service (needed for tool execution)
GRANT SELECT, REFERENCES ON SEMANTIC VIEW COFFEE_DEMO.ANALYTICS.COFFEE_SHOP_ANALYSIS TO ROLE PUBLIC;
GRANT USAGE ON CORTEX SEARCH SERVICE COFFEE_DEMO.ANALYTICS.COFFEE_KNOWLEDGE_SEARCH TO ROLE PUBLIC;
GRANT SELECT ON TABLE COFFEE_DEMO.ANALYTICS.STORES TO ROLE PUBLIC;
GRANT SELECT ON TABLE COFFEE_DEMO.ANALYTICS.ORDERS TO ROLE PUBLIC;
GRANT SELECT ON TABLE COFFEE_DEMO.ANALYTICS.ORDER_ITEMS TO ROLE PUBLIC;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE PUBLIC;

-- ============================================================
-- STEP 7: Access Snowflake Intelligence
-- ============================================================
-- Option A: Navigate to https://ai.snowflake.com
-- Option B: In Snowsight, go to AI & ML » Agents » Preview in Snowflake Intelligence
--
-- Try these demo questions:
--   "What was our total revenue by region?"
--   "Which store has the highest average order value?"
--   "Show me monthly sales trends as a chart"
--   "What are our coffee sourcing standards?"
--   "How does the loyalty program work?"

