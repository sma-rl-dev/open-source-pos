-- Deterministic baseline data for the Open Source POS tester environment.
--
-- Applied by `./tester-env seed` after `./tester-env deploy` (the deploy login
-- runs the migrations). Idempotent: every row the seed owns is deleted first,
-- then recreated with fixed ids, so running it twice converges on the same
-- state. Ids: suppliers people 2-4, customers people 5-10, items 1-15,
-- sales 1-4, receiving 1. Do not create records in that range by hand.
--
-- Dates are anchored to the seed day in the app timezone (app_config.timezone,
-- America/New_York) so a morning sale still lands on "today" for the sales
-- manage and report date filters. Within a day the times are fixed.
SET @tz = 'America/New_York';
SET @now = CONVERT_TZ(UTC_TIMESTAMP(), 'UTC', @tz);
SET @today = DATE(@now);
SET @opening = @today - INTERVAL 20 DAY + INTERVAL 8 HOUR;
SET @receiving = @today - INTERVAL 3 DAY + INTERVAL 8 HOUR + INTERVAL 30 MINUTE;
SET @sale1 = @today + INTERVAL 9 HOUR + INTERVAL 12 MINUTE;
SET @sale2 = @today + INTERVAL 10 HOUR + INTERVAL 40 MINUTE;
SET @sale3 = @today - INTERVAL 1 DAY + INTERVAL 15 HOUR + INTERVAL 20 MINUTE;
SET @sale4 = @today - INTERVAL 6 DAY + INTERVAL 12 HOUR + INTERVAL 5 MINUTE;

START TRANSACTION;

-- Children first: re-running the seed must not trip a foreign key.
DELETE FROM ospos_sales_items_taxes WHERE sale_id IN (1, 2, 3, 4);
DELETE FROM ospos_sales_taxes      WHERE sale_id IN (1, 2, 3, 4);
DELETE FROM ospos_sales_payments   WHERE sale_id IN (1, 2, 3, 4);
DELETE FROM ospos_sales_items      WHERE sale_id IN (1, 2, 3, 4);
DELETE FROM ospos_sales            WHERE sale_id IN (1, 2, 3, 4);
DELETE FROM ospos_receivings_items WHERE receiving_id = 1;
DELETE FROM ospos_receivings       WHERE receiving_id = 1;
DELETE FROM ospos_inventory        WHERE trans_items BETWEEN 1 AND 15;
DELETE FROM ospos_item_quantities  WHERE item_id BETWEEN 1 AND 15;
DELETE FROM ospos_items_taxes      WHERE item_id BETWEEN 1 AND 15;
DELETE FROM ospos_items            WHERE item_id BETWEEN 1 AND 15;
DELETE FROM ospos_customers        WHERE person_id BETWEEN 2 AND 10;
DELETE FROM ospos_suppliers        WHERE person_id BETWEEN 2 AND 4;
DELETE FROM ospos_people           WHERE person_id BETWEEN 2 AND 10;

-- Suppliers: coffee roaster, bakery and a broadline provisions distributor.
INSERT INTO ospos_people (person_id, first_name, last_name, phone_number, email, address_1, address_2, city, state, zip, country, comments) VALUES
(2, 'Dana', 'Whitlock', '555-0101', 'dana.whitlock@northwindroasters.example.com', '18 Mill Street', '', 'Beacon', 'NY', '12508', 'United States', ''),
(3, 'Luis', 'Moreau', '555-0102', 'luis.moreau@goldencrust.example.com', '640 Water Street', 'Suite 2', 'Poughkeepsie', 'NY', '12601', 'United States', ''),
(4, 'Erin', 'Kowalski', '555-0103', 'erin.kowalski@hvprovisions.example.com', '204 Foundry Road', '', 'Kingston', 'NY', '12401', 'United States', '');

INSERT INTO ospos_suppliers (person_id, company_name, agency_name, account_number, category) VALUES
(2, 'Northwind Coffee Roasters', 'Northwind Coffee Roasters', 'SUP-100', 0),
(3, 'Golden Crust Bakery', 'Golden Crust Bakery', 'SUP-101', 1),
(4, 'Hudson Valley Provisions', 'Hudson Valley Provisions', 'SUP-102', 2);

-- Customers: four company accounts, two individuals, one tax-exempt account.
INSERT INTO ospos_people (person_id, first_name, last_name, phone_number, email, address_1, address_2, city, state, zip, country, comments) VALUES
(5, 'Amelia', 'Hart', '555-0110', 'amelia.hart@example.com', '77 Union Avenue', 'Apt 3', 'New Paltz', 'NY', '12561', 'United States', ''),
(6, 'Marcus', 'Bell', '555-0111', 'marcus.bell@example.com', '12 Bayard Street', '', 'Kingston', 'NY', '12401', 'United States', ''),
(7, 'Priya', 'Raman', '555-0112', 'priya.raman@example.com', '310 Fair Street', '', 'Kingston', 'NY', '12401', 'United States', 'Tax-exempt community kitchen account'),
(8, 'Gabriel', 'Ortiz', '555-0113', 'gabriel.ortiz@example.com', '9 Albany Avenue', '', 'Kingston', 'NY', '12401', 'United States', ''),
(9, 'Hannah', 'Whitfield', '555-0114', 'hannah.whitfield@example.com', '55 Crown Street', '', 'Kingston', 'NY', '12401', 'United States', ''),
(10, 'Theo', 'Nakamura', '555-0115', 'theo.nakamura@example.com', '4 O\'Reilly Lane', '', 'Rosendale', 'NY', '12472', 'United States', '');

INSERT INTO ospos_customers (person_id, company_name, account_number, taxable, date, employee_id, discount, discount_type) VALUES
(5, 'Hart & Co. Studio', 'CUS-1001', 1, @today - INTERVAL 45 DAY, 1, 0.00, 0),
(6, NULL, 'CUS-1002', 1, @today - INTERVAL 32 DAY, 1, 0.00, 0),
(7, 'Raman Family', 'CUS-1003', 0, @today - INTERVAL 21 DAY, 1, 0.00, 0),
(8, 'Ortiz Catering', 'CUS-1004', 1, @today - INTERVAL 14 DAY, 1, 0.00, 0),
(9, 'Whitfield Dental', 'CUS-1005', 1, @today - INTERVAL 7 DAY, 1, 0.00, 0),
(10, NULL, 'CUS-1006', 1, @today - INTERVAL 3 DAY, 1, 0.00, 0);

-- 15 items over 6 categories. Taxable items carry a 'Sales Tax' 8% row; food
-- staples (bread, dairy, produce) are untaxed. Blueberry Muffin, Organic Kale
-- and Dish Soap sit at or below their reorder level (Dish Soap is at zero).
INSERT INTO ospos_items (item_id, name, category, supplier_id, item_number, description, cost_price, unit_price, reorder_level, receiving_quantity, allow_alt_description, is_serialized, deleted, stock_type, item_type, tax_category_id, qty_per_pack, pack_name) VALUES
(1, 'House Blend Coffee 12 oz', 'Coffee', 2, 'COF-1001', 'Medium roast whole-bean coffee, 12 oz bag', 8.00, 12.50, 10.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(2, 'Single Origin Espresso 12 oz', 'Coffee', 2, 'COF-1002', 'Guatemalan single origin, whole bean, 12 oz bag', 10.20, 15.75, 6.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(3, 'Sourdough Loaf', 'Bakery', 3, 'BAK-2001', 'Naturally leavened sourdough, baked daily', 3.10, 6.50, 8.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(4, 'Butter Croissant', 'Bakery', 3, 'BAK-2002', 'All-butter croissant, baked in store', 1.80, 4.25, 10.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(5, 'Blueberry Muffin', 'Bakery', 3, 'BAK-2003', 'Muffin with wild blueberries', 1.40, 3.75, 12.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(6, 'Whole Milk 1 gal', 'Dairy', 4, 'DRY-3001', 'Local whole milk, one gallon jug', 3.20, 4.99, 12.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(7, 'Sharp Cheddar 8 oz', 'Dairy', 4, 'DRY-3002', 'Aged sharp cheddar block, 8 oz', 4.60, 7.25, 6.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(8, 'Free-Range Eggs (12)', 'Dairy', 4, 'DRY-3003', 'One dozen large free-range eggs', 3.90, 5.49, 12.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(9, 'Hass Avocado (each)', 'Produce', NULL, 'PRD-4001', 'Ripe Hass avocado, sold individually', 0.95, 1.79, 20.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(10, 'Roma Tomatoes 1 lb', 'Produce', NULL, 'PRD-4002', 'Roma tomatoes, one pound', 1.30, 2.49, 10.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(11, 'Organic Kale Bunch', 'Produce', NULL, 'PRD-4003', 'Organic curly kale, one bunch', 1.75, 3.29, 8.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(12, 'Extra Virgin Olive Oil 500 ml', 'Pantry', 4, 'PAN-5001', 'Cold-pressed extra virgin olive oil, 500 ml', 12.40, 18.95, 5.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(13, 'Wildflower Honey 12 oz', 'Pantry', 4, 'PAN-5002', 'Raw wildflower honey, 12 oz jar', 7.25, 11.50, 4.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(14, 'Recycled Paper Towels 2-pack', 'Household', 4, 'HOM-6001', 'Two rolls of recycled paper towels', 6.10, 9.99, 8.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each'),
(15, 'Dish Soap 16 oz', 'Household', 4, 'HOM-6002', 'Plant-based dish soap, 16 oz bottle', 2.85, 5.25, 6.000, 1.000, 0, 0, 0, 0, 0, NULL, 1.000, 'Each');

INSERT INTO ospos_items_taxes (item_id, name, percent) VALUES
(1, 'Sales Tax', 8.000), (2, 'Sales Tax', 8.000), (4, 'Sales Tax', 8.000), (5, 'Sales Tax', 8.000),
(12, 'Sales Tax', 8.000), (13, 'Sales Tax', 8.000), (14, 'Sales Tax', 8.000), (15, 'Sales Tax', 8.000);

-- Current stock. Quantities already reflect the seeded receiving and sales.
INSERT INTO ospos_item_quantities (item_id, location_id, quantity) VALUES
(1, 1, 42.000), (2, 1, 18.000), (3, 1, 26.000), (4, 1, 34.000), (5, 1, 3.000),
(6, 1, 24.000), (7, 1, 11.000), (8, 1, 30.000), (9, 1, 60.000), (10, 1, 22.000),
(11, 1, 4.000), (12, 1, 15.000), (13, 1, 9.000), (14, 1, 20.000), (15, 1, 0.000);

-- Opening count 20 days ago, then a dairy delivery, then the sale movements.
INSERT INTO ospos_inventory (trans_items, trans_user, trans_date, trans_comment, trans_location, trans_inventory) VALUES
(1, 1, @opening, 'Opening stock count', 1, 44.000),
(2, 1, @opening, 'Opening stock count', 1, 18.000),
(3, 1, @opening, 'Opening stock count', 1, 27.000),
(4, 1, @opening, 'Opening stock count', 1, 36.000),
(5, 1, @opening, 'Opening stock count', 1, 5.000),
(6, 1, @opening, 'Opening stock count', 1, 21.000),
(7, 1, @opening, 'Opening stock count', 1, 9.000),
(8, 1, @opening, 'Opening stock count', 1, 25.000),
(9, 1, @opening, 'Opening stock count', 1, 63.000),
(10, 1, @opening, 'Opening stock count', 1, 22.000),
(11, 1, @opening, 'Opening stock count', 1, 4.000),
(12, 1, @opening, 'Opening stock count', 1, 16.000),
(13, 1, @opening, 'Opening stock count', 1, 10.000),
(14, 1, @opening, 'Opening stock count', 1, 22.000),
(15, 1, @opening, 'Opening stock count', 1, 1.000),
(6, 1, @receiving, 'Receiving RECV-1', 1, 4.000),
(7, 1, @receiving, 'Receiving RECV-1', 1, 2.000),
(8, 1, @receiving, 'Receiving RECV-1', 1, 6.000),
(1, 1, @sale1, 'Sale INV-000001', 1, -2.000),
(3, 1, @sale1, 'Sale INV-000001', 1, -1.000),
(6, 1, @sale2, 'Sale INV-000002', 1, -1.000),
(8, 1, @sale2, 'Sale INV-000002', 1, -1.000),
(9, 1, @sale2, 'Sale INV-000002', 1, -3.000),
(4, 1, @sale2, 'Sale INV-000002', 1, -2.000),
(12, 1, @sale3, 'Sale INV-000003', 1, -1.000),
(13, 1, @sale3, 'Sale INV-000003', 1, -1.000),
(5, 1, @sale3, 'Sale INV-000003', 1, -2.000),
(14, 1, @sale4, 'Sale INV-000004', 1, -2.000),
(15, 1, @sale4, 'Sale INV-000004', 1, -1.000);

-- One received delivery from the broadline distributor (dairy restock).
INSERT INTO ospos_receivings (receiving_id, receiving_time, supplier_id, employee_id, comment, payment_type, reference) VALUES
(1, @receiving, 4, 1, 'Weekly dairy delivery', 'Cash', 'PO-8842');

INSERT INTO ospos_receivings_items (receiving_id, item_id, description, line, quantity_purchased, item_cost_price, item_unit_price, discount, discount_type, item_location, receiving_quantity) VALUES
(1, 6, 'Whole Milk 1 gal', 1, 4.000, 3.20, 4.99, 0.00, 0, 1, 1.000),
(1, 7, 'Sharp Cheddar 8 oz', 2, 2.000, 4.60, 7.25, 0.00, 0, 1, 1.000),
(1, 8, 'Free-Range Eggs (12)', 3, 6.000, 3.90, 5.49, 0.00, 0, 1, 1.000);

-- Four completed sales across today, yesterday and six days ago.
-- Sale 3 is billed to a tax-exempt customer, so its taxable items carry no tax.
INSERT INTO ospos_sales (sale_id, sale_time, customer_id, employee_id, comment, invoice_number, sale_status, sale_type) VALUES
(1, @sale1, 5, 1, 'Morning coffee run', 'INV-000001', 0, 0),
(2, @sale2, 6, 1, 'Weekly grocery pickup', 'INV-000002', 0, 0),
(3, @sale3, 7, 1, 'Honey and olive oil restock', 'INV-000003', 0, 0),
(4, @sale4, 10, 1, 'Household supplies', 'INV-000004', 0, 0);

INSERT INTO ospos_sales_items (sale_id, item_id, description, line, quantity_purchased, item_cost_price, item_unit_price, discount, discount_type, item_location, print_option) VALUES
(1, 1, 'House Blend Coffee 12 oz', 1, 2.000, 8.00, 12.50, 0.00, 0, 1, 0),
(1, 3, 'Sourdough Loaf', 2, 1.000, 3.10, 6.50, 0.00, 0, 1, 0),
(2, 6, 'Whole Milk 1 gal', 1, 1.000, 3.20, 4.99, 0.00, 0, 1, 0),
(2, 8, 'Free-Range Eggs (12)', 2, 1.000, 3.90, 5.49, 0.00, 0, 1, 0),
(2, 9, 'Hass Avocado (each)', 3, 3.000, 0.95, 1.79, 0.00, 0, 1, 0),
(2, 4, 'Butter Croissant', 4, 2.000, 1.80, 4.25, 0.00, 0, 1, 0),
(3, 12, 'Extra Virgin Olive Oil 500 ml', 1, 1.000, 12.40, 18.95, 0.00, 0, 1, 0),
(3, 13, 'Wildflower Honey 12 oz', 2, 1.000, 7.25, 11.50, 0.00, 0, 1, 0),
(3, 5, 'Blueberry Muffin', 3, 2.000, 1.40, 3.75, 0.00, 0, 1, 0),
(4, 14, 'Recycled Paper Towels 2-pack', 1, 2.000, 6.10, 9.99, 0.00, 0, 1, 0),
(4, 15, 'Dish Soap 16 oz', 2, 1.000, 2.85, 5.25, 0.00, 0, 1, 0);

-- Per-line tax detail (Sales table totals add these; 8% of each taxable line).
INSERT INTO ospos_sales_items_taxes (sale_id, item_id, line, name, percent, tax_type, rounding_code, item_tax_amount) VALUES
(1, 1, 1, 'Sales Tax', 8.0000, 1, 0, 2.0000),
(2, 4, 4, 'Sales Tax', 8.0000, 1, 0, 0.6800),
(4, 14, 1, 'Sales Tax', 8.0000, 1, 0, 1.6000),
(4, 15, 2, 'Sales Tax', 8.0000, 1, 0, 0.4200);

-- Aggregated tax rows used by the tax reports and the receipt tax block.
INSERT INTO ospos_sales_taxes (sale_id, tax_type, tax_group, sale_tax_basis, sale_tax_amount, print_sequence, name, tax_rate, rounding_code) VALUES
(1, 1, 'Sales Tax', 25.0000, 2.0000, 1, 'Sales Tax', 8.0000, 0),
(2, 1, 'Sales Tax', 8.5000, 0.6800, 1, 'Sales Tax', 8.0000, 0),
(4, 1, 'Sales Tax', 25.2300, 2.0200, 1, 'Sales Tax', 8.0000, 0);

INSERT INTO ospos_sales_payments (sale_id, payment_type, payment_amount, cash_refund, cash_adjustment, employee_id, payment_time, reference_code) VALUES
(1, 'Cash', 33.50, 0.00, 0, 1, @sale1, ''),
(2, 'Credit Card', 25.03, 0.00, 0, 1, @sale2, 'AP-4471'),
(3, 'Debit Card', 37.95, 0.00, 0, 1, @sale3, 'POS-2210'),
(4, 'Cash', 27.25, 0.00, 0, 1, @sale4, '');

-- Store default tax. Upstream ships both tax names and rates empty, but the
-- item form always posts two tax rows and validates both: with blanks the save
-- is rejected ("Tax Name contains disallowed characters." then "Tax Percent
-- must be a non-negative value."). Ordinary store configuration prefills them,
-- so a default new-item form saves; the second 0% row is inert.
INSERT INTO ospos_app_config (`key`, `value`) VALUES
('default_tax_1_name', 'Sales Tax'),
('default_tax_1_rate', '8'),
('default_tax_2_name', 'Tax 2'),
('default_tax_2_rate', '0')
ON DUPLICATE KEY UPDATE `value` = VALUES(`value`);

COMMIT;
