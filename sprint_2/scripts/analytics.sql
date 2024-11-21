WITH overall_avg_check AS (SELECT
    restaurant_uuid,
    ROUND(AVG(avg_check), 2) AS avg_check
FROM cafe.sales
GROUP BY restaurant_uuid),
ranks AS (SELECT
    r.name,
    r.restaurant_type,
    c.avg_check,
    ROW_NUMBER() OVER (PARTITION BY r.restaurant_type ORDER BY c.avg_check DESC) AS rank
FROM cafe.restaurants r
LEFT JOIN overall_avg_check c USING (restaurant_uuid))

SELECT
    name AS "Название заведения",
    CASE restaurant_type
        WHEN 'coffee_shop' THEN 'Кофейня'
        WHEN 'restaurant' THEN 'Ресторан'
        WHEN 'bar' THEN 'Бар'
        WHEN 'pizzeria' THEN 'Пиццерия'
    END AS "Тип заведения",
    avg_check AS "Средний чек"
FROM ranks
WHERE rank <= 3
ORDER BY restaurant_type, rank;

CREATE MATERIALIZED VIEW IF NOT EXISTS cafe.v_avg_check AS
     WITH avg_check_by_year AS (SELECT
                               restaurant_uuid,
                               EXTRACT(year FROM date) AS year,
                               ROUND(AVG(avg_check), 2) AS avg_check
                           FROM cafe.sales
                           GROUP BY restaurant_uuid, year),
     result AS (SELECT
                    c.year,
                    r.name,
                    r.restaurant_type,
                    c.avg_check,
                    LAG(c.avg_check) OVER (PARTITION BY restaurant_uuid ORDER BY year) AS previous_avg_check,
                    (c.avg_check / LAG(c.avg_check) OVER (PARTITION BY restaurant_uuid ORDER BY year) - 1) * 100 AS diff
                FROM avg_check_by_year c
                         LEFT JOIN cafe.restaurants r USING (restaurant_uuid)
                WHERE year != 2023
                ORDER BY restaurant_uuid, year)
    SELECT
    year AS "Год",
    name AS "Название заведения",
    CASE restaurant_type
        WHEN 'coffee_shop' THEN 'Кофейня'
        WHEN 'restaurant' THEN 'Ресторан'
        WHEN 'bar' THEN 'Бар'
        WHEN 'pizzeria' THEN 'Пиццерия'
    END AS "Тип заведения",
    avg_check AS "Средний чек в этом году",
    previous_avg_check AS "Средний чек в предыдущем году",
    diff AS "Изменение среднего чека в %"
FROM result;

SELECT
    c.name,
    COUNT(DISTINCT m.manager_uuid) AS managers_count
FROM cafe.restaurant_manager_work_dates m
LEFT JOIN cafe.restaurants c USING (restaurant_uuid)
GROUP BY c.name
ORDER BY managers_count DESC
LIMIT 3;

WITH pizzas AS (SELECT
                    name,
                    JSONB_EACH_TEXT(menu -> 'Пицца') AS pizza
FROM cafe.restaurants
WHERE restaurant_type = 'pizzeria'),
pizza_count AS (SELECT
    name,
    COUNT(*) AS count,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS rank
FROM pizzas
GROUP BY name)

SELECT
    name AS "Название заведения	",
    count AS "Количество пицц в меню"
FROM pizza_count
WHERE rank = 1;

WITH pizzas AS (SELECT
                    r.name AS restaurant_name,
                    pizza.key AS pizza_name,
                    pizza.value AS pizza_price,
                    ROW_NUMBER() OVER (PARTITION BY r.name ORDER BY pizza.value DESC) AS RANK
    FROM cafe.restaurants r,
    JSONB_EACH_TEXT(r.menu -> 'Пицца') AS pizza
    WHERE restaurant_type = 'pizzeria')

SELECT
    restaurant_name AS "Название заведения",
    'Пицца' AS "Тип блюда",
    pizza_name AS "Название пиццы",
    pizza_price AS "Цена"
FROM pizzas
WHERE RANK = 1;

WITH closest_rests AS (SELECT
    r1.name AS name1,
    r2.name AS name2,
    r1.restaurant_type AS type,
    MIN(ST_DISTANCE(r1.location, r2.location)) AS min_dist
FROM cafe.restaurants r1
JOIN cafe.restaurants r2 ON (r1.restaurant_type = r2.restaurant_type AND r1.name != r2.name)
GROUP BY  r1.name, r2.name, r1.restaurant_type
ORDER BY min_dist
LIMIT 1)

SELECT
    name1 AS "Название Заведения 1",
    name2 AS "Название Заведения 2",
    CASE type
        WHEN 'coffee_shop' THEN 'Кофейня'
        WHEN 'restaurant' THEN 'Ресторан'
        WHEN 'bar' THEN 'Бар'
        WHEN 'pizzeria' THEN 'Пиццерия'
        END AS "Тип заведения",
    min_dist AS "Расстояние"
FROM closest_rests;

WITH restaurants_by_district_count AS (SELECT
    d.district_name,
    COUNT(r.restaurant_uuid) AS restaurants_count
FROM cafe.districts d
LEFT JOIN cafe.restaurants r ON (ST_WITHIN(r.location::geometry, d.district_geom))
GROUP BY d.district_name)

SELECT
    district_name AS "Название района",
    restaurants_count AS "Количество заведений"
FROM (SELECT *
      FROM restaurants_by_district_count
      ORDER BY restaurants_count DESC
      LIMIT 1) as r
UNION (SELECT *
       FROM restaurants_by_district_count
       ORDER BY restaurants_count
       LIMIT 1)
ORDER BY "Количество заведений" DESC;