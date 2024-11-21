SELECT ROUND((COUNT(*)-COUNT(gasoline_consumption))/(COUNT(*)::NUMERIC(5,2)/100)) AS nulls_percentage_gasoline_consumption
FROM car_shop.models;

SELECT
    b.name AS brand_name,
    EXTRACT(year FROM s.date) AS year,
    ROUND(AVG(s.price), 2) AS price_avg
FROM car_shop.sales s
LEFT JOIN car_shop.models m ON m.id = s.model_id
LEFT JOIN car_shop.brands b ON b.id = m.brand_id
GROUP BY b.name, year
ORDER BY brand_name, year;

SELECT
    EXTRACT(month FROM s.date) AS month,
    EXTRACT(year FROM s.date) AS year,
    ROUND(AVG(s.price), 2) AS price_avg
FROM GENERATE_SERIES(1, 12) AS period_month
LEFT JOIN car_shop.sales s ON EXTRACT(year FROM s.date) = 2022 AND EXTRACT(month FROM s.date) = period_month
GROUP BY month, year
ORDER BY month;

SELECT
    CONCAT(c.first_name, ' ', c.last_name) AS person,
    STRING_AGG(CONCAT(b.name, ' ', m.name), ', ') AS cars
FROM car_shop.sales s
LEFT JOIN car_shop.customers c ON c.id = s.customer_id
LEFT JOIN car_shop.models m ON m.id = s.model_id
LEFT JOIN car_shop.brands b ON b.id = m.brand_id
GROUP BY c.id, c.first_name, c.last_name
ORDER BY person;

SELECT
    c.name AS brand_origin,
    MAX((s.price / (100 - s.discount) * 100)::numeric(9, 2)) AS price_max,
    MIN((s.price / (100 - s.discount) * 100)::numeric(9, 2)) AS price_min
FROM car_shop.countries c
LEFT JOIN car_shop.brands b on c.id = b.origin_id
LEFT JOIN car_shop.models m on b.id = m.brand_id
LEFT JOIN car_shop.sales s on m.id = s.model_id
GROUP BY c.name;

SELECT COUNT(*)
FROM car_shop.customers
WHERE phone_number LIKE '+1%';


