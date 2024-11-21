INSERT INTO car_shop.countries (name)
SELECT DISTINCT brand_origin FROM raw_data.sales
WHERE brand_origin IS NOT NULL;

INSERT INTO car_shop.brands (name, origin_id)
SELECT DISTINCT SPLIT_PART(auto, ' ', 1),c.id
FROM raw_data.sales AS s
LEFT JOIN car_shop.countries AS c ON (s.brand_origin = c.name OR (s.brand_origin IS NULL AND c.name = 'Germany'));

INSERT INTO car_shop.models (name, brand_id, gasoline_consumption)
SELECT DISTINCT
    SUBSTRING(
            s.auto,
            STRPOS(s.auto, ' ')+1,
            (STRPOS(s.auto, ',')-STRPOS(s.auto, ' '))-1
    ),
    b.id, gasoline_consumption
FROM raw_data.sales AS s
LEFT JOIN car_shop.brands AS b ON (SPLIT_PART(auto, ' ', 1) = b.name);

INSERT INTO car_shop.colors (name)
SELECT DISTINCT
    SUBSTRING(
            auto,
            STRPOS(auto, ',')+2
    )
FROM raw_data.sales;

INSERT INTO car_shop.customers (first_name, last_name, phone_number)
SELECT DISTINCT
    CASE
        WHEN LOWER(SPLIT_PART(person, ' ', 1)) = 'mrs.'
            OR LOWER(SPLIT_PART(person, ' ', 1)) = 'mr.'
            OR LOWER(SPLIT_PART(person, ' ', 1)) = 'dr.'
            OR LOWER(SPLIT_PART(person, ' ', 1)) = 'miss'
        THEN SPLIT_PART(person, ' ', 2)
        ELSE SPLIT_PART(person, ' ', 1)
    END,
    CASE
        WHEN LOWER(SPLIT_PART(person, ' ', 1)) = 'mrs.'
            OR LOWER(SPLIT_PART(person, ' ', 1)) = 'mr.'
            OR LOWER(SPLIT_PART(person, ' ', 1)) = 'dr.'
            OR LOWER(SPLIT_PART(person, ' ', 1)) = 'miss'
            THEN SPLIT_PART(person, ' ', 3)
        ELSE SPLIT_PART(person, ' ', 2)
    END, phone
FROM raw_data.sales;

INSERT INTO car_shop.sales (model_id, color_id, price, discount, customer_id, date)
SELECT DISTINCT m.id, col.id, s.price, s.discount, cust.id, s.date
FROM raw_data.sales AS s
LEFT JOIN car_shop.brands AS b ON (SPLIT_PART(s.auto, ' ', 1) = b.name)
LEFT JOIN car_shop.models m ON b.id = m.brand_id AND SUBSTRING(
                                                              s.auto,
                                                              STRPOS(s.auto, ' ')+1,
                                                              (STRPOS(s.auto, ',')-STRPOS(s.auto, ' '))-1
                                                      ) = m.name
LEFT JOIN car_shop.colors AS col ON SUBSTRING(
                                           s.auto,
                                           STRPOS(s.auto, ',') + 2
                                   ) = col.name
LEFT JOIN car_shop.customers AS cust ON s.phone = cust.phone_number;