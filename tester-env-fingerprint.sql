-- Stable digest of the seeded baseline. Excludes row ids and timestamps so the
-- value is comparable across resets; compare it after two reset+deploy+seed
-- cycles to prove the seed is deterministic. Printed by `./tester-env seed`.
SET SESSION group_concat_max_len = 1000000;

SELECT SHA2(GROUP_CONCAT(line ORDER BY line SEPARATOR '\n'), 256) AS fingerprint
FROM (
    SELECT CONCAT('item|', i.item_number, '|', i.name, '|', i.category, '|', i.cost_price, '|', i.unit_price,
                  '|', i.reorder_level, '|', IFNULL(q.quantity, 0)) AS line
    FROM ospos_items i
    LEFT JOIN ospos_item_quantities q ON q.item_id = i.item_id AND q.location_id = 1
    WHERE i.item_id BETWEEN 1 AND 15
    UNION ALL
    SELECT CONCAT('itemtax|', i.item_number, '|', t.name, '|', t.percent)
    FROM ospos_items_taxes t JOIN ospos_items i ON i.item_id = t.item_id
    WHERE i.item_id BETWEEN 1 AND 15
    UNION ALL
    SELECT CONCAT('customer|', c.account_number, '|', p.first_name, ' ', p.last_name, '|',
                  IFNULL(c.company_name, ''), '|', c.taxable)
    FROM ospos_customers c JOIN ospos_people p ON p.person_id = c.person_id
    WHERE c.person_id BETWEEN 5 AND 10
    UNION ALL
    SELECT CONCAT('supplier|', s.account_number, '|', s.company_name, '|', p.first_name, ' ', p.last_name)
    FROM ospos_suppliers s JOIN ospos_people p ON p.person_id = s.person_id
    WHERE s.person_id BETWEEN 2 AND 4
    UNION ALL
    SELECT CONCAT('sale|', s.invoice_number, '|', IFNULL(p.first_name, ''), ' ', IFNULL(p.last_name, ''), '|',
                  s.comment, '|', COUNT(si.item_id), '|', SUM(si.quantity_purchased), '|',
                  SUM(si.quantity_purchased * si.item_unit_price), '|', IFNULL(SUM(sit.item_tax_amount), 0), '|',
                  pay.payment_type, '|', pay.payment_amount)
    FROM ospos_sales s
    LEFT JOIN ospos_people p ON p.person_id = s.customer_id
    LEFT JOIN ospos_sales_items si ON si.sale_id = s.sale_id
    LEFT JOIN ospos_sales_items_taxes sit ON sit.sale_id = si.sale_id AND sit.item_id = si.item_id AND sit.line = si.line
    LEFT JOIN ospos_sales_payments pay ON pay.sale_id = s.sale_id
    WHERE s.sale_id BETWEEN 1 AND 4
    GROUP BY s.sale_id, pay.payment_type, pay.payment_amount
    UNION ALL
    SELECT CONCAT('receiving|', r.reference, '|', s.company_name, '|', COUNT(ri.item_id), '|', SUM(ri.quantity_purchased), '|',
                  SUM(ri.quantity_purchased * ri.item_cost_price))
    FROM ospos_receivings r
    JOIN ospos_suppliers s ON s.person_id = r.supplier_id
    JOIN ospos_receivings_items ri ON ri.receiving_id = r.receiving_id
    WHERE r.receiving_id = 1
    GROUP BY r.receiving_id, r.reference, s.company_name
) normalized;
