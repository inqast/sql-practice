SELECT order_dt
FROM orders
WHERE order_id = 153;

SELECT order_id
FROM orders
WHERE order_dt > current_date::timestamp;

SELECT count(*)
FROM orders
WHERE user_id = '329551a1-215d-43e6-baee-322f2467272d';

EXPLAIN INSERT INTO orders
(order_id, order_dt, user_id, device_type, city_id, total_cost, discount,
 final_cost)
SELECT MAX(order_id) + 1, current_timestamp,
       '329551a1-215d-43e6-baee-322f2467272d',
       'Mobile', 1, 1000.00, null, 1000.00
FROM orders;