-- TOP 1 --
-- 15 s 387 ms
SELECT count(*)
FROM order_statuses os
         JOIN orders o ON o.order_id = os.order_id
WHERE (SELECT count(*)
       FROM order_statuses os1
       WHERE os1.order_id = o.order_id AND os1.status_id = 2) = 0
  AND o.city_id = 1;
/*
Aggregate  (cost=61006668.41..61006668.42 rows=1 width=8) (actual time=23755.251..23755.253 rows=1 loops=1)
  ->  Nested Loop  (cost=0.30..61006668.19 rows=90 width=0) (actual time=113.585..23754.755 rows=1190 loops=1)
        ->  Seq Scan on order_statuses os  (cost=0.00..2035.34 rows=124334 width=8) (actual time=0.013..7.086 rows=124334 loops=1)
        ->  Memoize  (cost=0.30..2657.36 rows=1 width=8) (actual time=0.191..0.191 rows=0 loops=124334)
              Cache Key: os.order_id
              Cache Mode: logical
              Hits: 96650  Misses: 27684  Evictions: 0  Overflows: 0  Memory Usage: 1994kB
              ->  Index Scan using orders_order_id_idx on orders o  (cost=0.29..2657.35 rows=1 width=8) (actual time=0.853..0.853 rows=0 loops=27684)
                    Index Cond: (order_id = os.order_id)
                    Filter: ((city_id = 1) AND ((SubPlan 1) = 0))
                    Rows Removed by Filter: 1
                    SubPlan 1
                      ->  Aggregate  (cost=2657.01..2657.02 rows=1 width=8) (actual time=5.961..5.961 rows=1 loops=3958)
                            ->  Seq Scan on order_statuses os1  (cost=0.00..2657.01 rows=1 width=0) (actual time=3.820..5.959 rows=1 loops=3958)
                                  Filter: ((order_id = o.order_id) AND (status_id = 2))
                                  Rows Removed by Filter: 124333
*/

/*
Здесь есть созависимый запрос из таблицы order_statuses, который выполняется 3958 раза, полностью перебирая таблицу order_statuses.
В новом варианте мы вынесем получение идентификаторов в общее табличное выражение, которое будет рассчитано единожды
Так же заменим проверку условия на слияние, которое происходит достаточно производительным хэш-методом.

*/

-- 57 ms
WITH unpaid_orders AS (
    SELECT order_id
    FROM order_statuses
    GROUP BY order_id
    HAVING MAX(status_id) < 2
)
SELECT count(*)
FROM orders o
         JOIN unpaid_orders uo ON o.order_id = uo.order_id
    AND o.city_id = 1;
/*
Aggregate  (cost=3790.29..3790.30 rows=1 width=8) (actual time=43.938..43.946 rows=1 loops=1)
  ->  Hash Join  (cost=3116.12..3787.56 rows=1094 width=0) (actual time=40.114..43.866 rows=1190 loops=1)
        Hash Cond: (o.order_id = order_statuses.order_id)
        ->  Seq Scan on orders o  (cost=0.00..661.05 rows=3958 width=8) (actual time=0.026..2.673 rows=3958 loops=1)
              Filter: (city_id = 1)
              Rows Removed by Filter: 23726
        ->  Hash  (cost=3020.47..3020.47 rows=7652 width=8) (actual time=40.010..40.015 rows=8354 loops=1)
              Buckets: 16384 (originally 8192)  Batches: 1 (originally 1)  Memory Usage: 455kB
              ->  HashAggregate  (cost=2657.01..2943.95 rows=7652 width=8) (actual time=35.516..39.005 rows=8354 loops=1)
                    Group Key: order_statuses.order_id
                    Filter: (max(order_statuses.status_id) < 2)
                    Batches: 1  Memory Usage: 3857kB
                    Rows Removed by Filter: 19330
                    ->  Seq Scan on order_statuses  (cost=0.00..2035.34 rows=124334 width=12) (actual time=0.009..9.261 rows=124334 loops=1)
*/

-- TOP 2 --
-- 539 ms
SELECT *
FROM user_logs
WHERE datetime::date > current_date;

/*
Тут не работает индекс по datetime из за преобразования данных, избавимся от него.
*/

-- 21 ms
SELECT *
FROM user_logs
WHERE datetime > current_date::timestamp;

-- TOP 3 --
-- 462 ms
EXPLAIN SELECT event, datetime
FROM user_logs
WHERE visitor_uuid = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'
ORDER BY 2;
/*
Gather Merge  (cost=92017.63..92040.96 rows=200 width=19)
  Workers Planned: 2
  ->  Sort  (cost=91017.60..91017.85 rows=100 width=19)
        Sort Key: user_logs.datetime
        ->  Parallel Append  (cost=0.00..91014.28 rows=100 width=19)
              ->  Parallel Seq Scan on user_logs_y2021q2 user_logs_2  (cost=0.00..66408.25 rows=60 width=18)
                    Filter: ((visitor_uuid)::text = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'::text)
              ->  Parallel Seq Scan on user_logs user_logs_1  (cost=0.00..24045.52 rows=32 width=18)
                    Filter: ((visitor_uuid)::text = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'::text)
              ->  Parallel Seq Scan on user_logs_y2021q3 user_logs_3  (cost=0.00..549.06 rows=10 width=18)
                    Filter: ((visitor_uuid)::text = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'::text)
              ->  Parallel Seq Scan on user_logs_y2021q4 user_logs_4  (cost=0.00..10.96 rows=1 width=282)
                    Filter: ((visitor_uuid)::text = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'::text)
*/

/*
В данном запросе видим последовательно сканирование по visitor_id во всех партициях.
Что бы перейти к более эффективной выборке строк из таблицы с партициями продублировали по ним индексы по искомому полю.
*/

CREATE INDEX IF NOT EXISTS user_logs_visitor_uuid_idx ON user_logs (visitor_uuid);
CREATE INDEX IF NOT EXISTS user_logs_visitor_y2021q2_uuid_idx ON user_logs_y2021q2 (visitor_uuid);
CREATE INDEX IF NOT EXISTS user_logs_visitor_y2021q3_uuid_idx ON user_logs_y2021q3 (visitor_uuid);
CREATE INDEX IF NOT EXISTS user_logs_visitor_y2021q4_uuid_idx ON user_logs_y2021q4 (visitor_uuid);

-- 23 ms
SELECT event, datetime
        FROM user_logs
        WHERE visitor_uuid = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'
        ORDER BY 2;
/*
Sort  (cost=939.03..939.62 rows=239 width=19)
  Sort Key: user_logs.datetime
  ->  Append  (cost=5.02..929.59 rows=239 width=19)
        ->  Bitmap Heap Scan on user_logs user_logs_1  (cost=5.02..295.00 rows=76 width=18)
              Recheck Cond: ((visitor_uuid)::text = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'::text)
              ->  Bitmap Index Scan on user_logs_visitor_uuid_idx  (cost=0.00..5.00 rows=76 width=0)
                    Index Cond: ((visitor_uuid)::text = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'::text)
        ->  Bitmap Heap Scan on user_logs_y2021q2 user_logs_2  (cost=5.55..563.63 rows=145 width=18)
              Recheck Cond: ((visitor_uuid)::text = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'::text)
              ->  Bitmap Index Scan on user_logs_visitor_y2021q2_uuid_idx  (cost=0.00..5.52 rows=145 width=0)
                    Index Cond: ((visitor_uuid)::text = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'::text)
        ->  Bitmap Heap Scan on user_logs_y2021q3 user_logs_3  (cost=4.42..61.59 rows=17 width=18)
              Recheck Cond: ((visitor_uuid)::text = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'::text)
              ->  Bitmap Index Scan on user_logs_visitor_y2021q3_uuid_idx  (cost=0.00..4.42 rows=17 width=0)
                    Index Cond: ((visitor_uuid)::text = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'::text)
        ->  Index Scan using user_logs_visitor_y2021q4_uuid_idx on user_logs_y2021q4 user_logs_4  (cost=0.14..8.16 rows=1 width=282)
              Index Cond: ((visitor_uuid)::text = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'::text)
*/

-- TOP 4 --
-- 138 ms
SELECT o.order_id, o.order_dt, o.final_cost, s.status_name
FROM order_statuses os
         JOIN orders o ON o.order_id = os.order_id
         JOIN statuses s ON s.status_id = os.status_id
WHERE o.user_id = 'c2885b45-dddd-4df3-b9b3-2cc012df727c'::uuid
  AND os.status_dt IN (
    SELECT max(status_dt)
    FROM order_statuses
    WHERE order_id = o.order_id
);
/*
Nested Loop  (cost=15.51..33173.85 rows=44 width=54) (actual time=110.448..110.454 rows=2 loops=1)
  Join Filter: (os.status_id = s.status_id)
  Rows Removed by Join Filter: 10
  ->  Seq Scan on statuses s  (cost=0.00..22.70 rows=1270 width=36) (actual time=0.014..0.015 rows=6 loops=1)
  ->  Materialize  (cost=15.51..33017.82 rows=7 width=26) (actual time=10.397..18.404 rows=2 loops=6)
        ->  Hash Join  (cost=15.51..33017.78 rows=7 width=26) (actual time=62.375..110.411 rows=2 loops=1)
              Hash Cond: (os.order_id = o.order_id)
              Join Filter: (SubPlan 1)
              Rows Removed by Join Filter: 10
              ->  Seq Scan on order_statuses os  (cost=0.00..2035.34 rows=124334 width=20) (actual time=0.005..9.580 rows=124334 loops=1)
              ->  Hash  (cost=15.47..15.47 rows=3 width=22) (actual time=0.069..0.070 rows=2 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    ->  Bitmap Heap Scan on orders o  (cost=4.31..15.47 rows=3 width=22) (actual time=0.058..0.060 rows=2 loops=1)
                          Recheck Cond: (user_id = 'c2885b45-dddd-4df3-b9b3-2cc012df727c'::uuid)
                          Heap Blocks: exact=1
                          ->  Bitmap Index Scan on orders_user_id_idx  (cost=0.00..4.31 rows=3 width=0) (actual time=0.023..0.023 rows=2 loops=1)
                                Index Cond: (user_id = 'c2885b45-dddd-4df3-b9b3-2cc012df727c'::uuid)
              SubPlan 1
                ->  Aggregate  (cost=2346.19..2346.20 rows=1 width=8) (actual time=7.328..7.328 rows=1 loops=12)
                      ->  Seq Scan on order_statuses  (cost=0.00..2346.18 rows=5 width=8) (actual time=7.288..7.321 rows=6 loops=12)
                            Filter: (order_id = o.order_id)
                            Rows Removed by Filter: 124328
*/

/*
В данном запросе происходит объемное объединение таблиц с помощью вложенного цикла, часть из которых перебирается последовательно.
Так же в условии есть зависимый от строки запрос.
Мы избавимся от условия в пользу объединения и сократим объем объединяемых таблиц.
*/

-- 44 ms
SELECT o.order_id, o.order_dt, o.final_cost, s.status_name
FROM (SELECT * FROM orders WHERE user_id = 'c2885b45-dddd-4df3-b9b3-2cc012df727c'::uuid) o
         JOIN (SELECT order_id, max(status_id) as status_id
               FROM order_statuses
               GROUP BY order_id) os ON o.order_id = os.order_id
         JOIN statuses s ON s.status_id = os.status_id;
/*
Hash Join  (cost=3217.74..3245.34 rows=13 width=54) (actual time=40.222..40.233 rows=2 loops=1)
  Hash Cond: (s.status_id = (max(order_statuses.status_id)))
  ->  Seq Scan on statuses s  (cost=0.00..22.70 rows=1270 width=36) (actual time=0.018..0.022 rows=6 loops=1)
  ->  Hash  (cost=3217.72..3217.72 rows=2 width=26) (actual time=40.158..40.166 rows=2 loops=1)
        Buckets: 1024  Batches: 1  Memory Usage: 9kB
        ->  Hash Join  (cost=2672.52..3217.72 rows=2 width=26) (actual time=36.411..40.160 rows=2 loops=1)
              Hash Cond: (order_statuses.order_id = orders.order_id)
              ->  HashAggregate  (cost=2657.01..2886.56 rows=22955 width=12) (actual time=33.981..37.764 rows=27684 loops=1)
                    Group Key: order_statuses.order_id
                    Batches: 1  Memory Usage: 3857kB
                    ->  Seq Scan on order_statuses  (cost=0.00..2035.34 rows=124334 width=12) (actual time=0.005..8.234 rows=124334 loops=1)
              ->  Hash  (cost=15.47..15.47 rows=3 width=22) (actual time=0.050..0.052 rows=2 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    ->  Bitmap Heap Scan on orders  (cost=4.31..15.47 rows=3 width=22) (actual time=0.040..0.042 rows=2 loops=1)
                          Recheck Cond: (user_id = 'c2885b45-dddd-4df3-b9b3-2cc012df727c'::uuid)
                          Heap Blocks: exact=1
                          ->  Bitmap Index Scan on orders_user_id_idx  (cost=0.00..4.31 rows=3 width=0) (actual time=0.027..0.027 rows=2 loops=1)
                                Index Cond: (user_id = 'c2885b45-dddd-4df3-b9b3-2cc012df727c'::uuid)
*/


-- TOP 5 --
-- 72 ms
SELECT d.name, SUM(count) AS orders_quantity
FROM order_items oi
         JOIN dishes d ON d.object_id = oi.item
WHERE oi.item IN (
    SELECT item
    FROM (SELECT item, SUM(count) AS total_sales
          FROM order_items oi
          GROUP BY 1) dishes_sales
    WHERE dishes_sales.total_sales > (
        SELECT SUM(t.total_sales)/ COUNT(*)
        FROM (SELECT item, SUM(count) AS total_sales
              FROM order_items oi
              GROUP BY
                  1) t)
)
GROUP BY 1
ORDER BY orders_quantity DESC;
/*
Sort  (cost=4808.91..4810.74 rows=735 width=66) (actual time=61.628..61.652 rows=362 loops=1)
  Sort Key: (sum(oi.count)) DESC
  Sort Method: quicksort  Memory: 54kB
  InitPlan 1 (returns $0)
    ->  Aggregate  (cost=1501.65..1501.66 rows=1 width=32) (actual time=16.316..16.318 rows=1 loops=1)
          ->  HashAggregate  (cost=1480.72..1490.23 rows=761 width=40) (actual time=16.063..16.170 rows=761 loops=1)
                Group Key: oi_2.item
                Batches: 1  Memory Usage: 169kB
                ->  Seq Scan on order_items oi_2  (cost=0.00..1134.48 rows=69248 width=16) (actual time=0.012..4.174 rows=69248 loops=1)
  ->  HashAggregate  (cost=3263.06..3272.25 rows=735 width=66) (actual time=61.422..61.491 rows=362 loops=1)
        Group Key: d.name
        Batches: 1  Memory Usage: 169kB
        ->  Hash Join  (cost=1522.66..3147.65 rows=23083 width=42) (actual time=38.541..53.747 rows=35854 loops=1)
              Hash Cond: (oi.item = d.object_id)
              ->  Seq Scan on order_items oi  (cost=0.00..1134.48 rows=69248 width=16) (actual time=0.046..4.625 rows=69248 loops=1)
              ->  Hash  (cost=1519.48..1519.48 rows=254 width=50) (actual time=38.477..38.480 rows=366 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 39kB
                    ->  Hash Join  (cost=1497.85..1519.48 rows=254 width=50) (actual time=38.245..38.429 rows=366 loops=1)
                          Hash Cond: (d.object_id = dishes_sales.item)
                          ->  Seq Scan on dishes d  (cost=0.00..19.62 rows=762 width=42) (actual time=0.014..0.090 rows=762 loops=1)
                          ->  Hash  (cost=1494.67..1494.67 rows=254 width=8) (actual time=38.216..38.218 rows=366 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 23kB
                                ->  Subquery Scan on dishes_sales  (cost=1480.72..1494.67 rows=254 width=8) (actual time=37.983..38.171 rows=366 loops=1)
                                      ->  HashAggregate  (cost=1480.72..1492.13 rows=254 width=40) (actual time=37.982..38.139 rows=366 loops=1)
                                            Group Key: oi_1.item
                                            Filter: (sum(oi_1.count) > $0)
                                            Batches: 1  Memory Usage: 169kB
                                            Rows Removed by Filter: 395
                                            ->  Seq Scan on order_items oi_1  (cost=0.00..1134.48 rows=69248 width=16) (actual time=0.005..6.999 rows=69248 loops=1)
*/

/*
В данном запросе используется тяжелое условие вхождения в список идентификаторов и вложенный запрос в условии
Для ускорения запроса используем общие табличные выражения и объединения таблиц.
*/

-- 48 ms
WITH
    avg_sales AS (
        SELECT SUM(t.total_sales)/ COUNT(*)
        FROM (SELECT item, SUM(count) AS total_sales
              FROM order_items oi
              GROUP BY item
             ) t),
    items AS (SELECT item, SUM(count) as orders_quantity
              FROM order_items oi
              GROUP BY item
              HAVING SUM(count) > (SELECT * FROM avg_sales)
)
SELECT d.name, i.orders_quantity
FROM  items i
         JOIN dishes d ON d.object_id = i.item
ORDER BY orders_quantity DESC;

/*
Sort  (cost=3031.30..3031.94 rows=254 width=66) (actual time=41.310..41.333 rows=366 loops=1)
  Sort Key: i.orders_quantity DESC
  Sort Method: quicksort  Memory: 54kB
  ->  Hash Join  (cost=2999.52..3021.16 rows=254 width=66) (actual time=40.992..41.194 rows=366 loops=1)
        Hash Cond: (d.object_id = i.item)
        ->  Seq Scan on dishes d  (cost=0.00..19.62 rows=762 width=42) (actual time=0.024..0.092 rows=762 loops=1)
        ->  Hash  (cost=2996.35..2996.35 rows=254 width=40) (actual time=40.954..40.957 rows=366 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 26kB
              ->  Subquery Scan on i  (cost=2982.39..2996.35 rows=254 width=40) (actual time=40.717..40.883 rows=366 loops=1)
                    ->  HashAggregate  (cost=2982.39..2993.81 rows=254 width=40) (actual time=40.716..40.849 rows=366 loops=1)
                          Group Key: oi.item
                          Filter: (sum(oi.count) > $0)
                          Batches: 1  Memory Usage: 169kB
                          Rows Removed by Filter: 395
                          InitPlan 1 (returns $0)
                            ->  Aggregate  (cost=1501.65..1501.66 rows=1 width=32) (actual time=15.733..15.734 rows=1 loops=1)
                                  ->  HashAggregate  (cost=1480.72..1490.23 rows=761 width=40) (actual time=15.554..15.657 rows=761 loops=1)
                                        Group Key: oi_1.item
                                        Batches: 1  Memory Usage: 169kB
                                        ->  Seq Scan on order_items oi_1  (cost=0.00..1134.48 rows=69248 width=16) (actual time=0.010..4.104 rows=69248 loops=1)
                          ->  Seq Scan on order_items oi  (cost=0.00..1134.48 rows=69248 width=16) (actual time=0.006..6.247 rows=69248 loops=1)
*/