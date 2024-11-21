-- Создание схем и таблиц

CREATE SCHEMA IF NOT EXISTS raw_data;
CREATE SCHEMA IF NOT EXISTS car_shop;

CREATE TABLE IF NOT EXISTS raw_data.sales (
                                              id SERIAL PRIMARY KEY,
                                              auto VARCHAR(30),
                                              gasoline_consumption NUMERIC(4,2),
                                              price NUMERIC(9,2),
                                              date DATE,
                                              person VARCHAR(30),
                                              phone VARCHAR(30),
                                              discount SMALLINT,
                                              brand_origin VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS car_shop.countries ( -- Вынес страны отдельно для нормализации
                                                  id SERIAL PRIMARY KEY,
                                                  name VARCHAR(60) NOT NULL UNIQUE -- 60 символов что для полного названия ирландии, уникальность что бы не плодить неоднозначные отображения.
);

CREATE TABLE IF NOT EXISTS car_shop.brands ( -- Бренды так же вынес отдельно со ссылкой на страны
                                               id SERIAL PRIMARY KEY,
                                               name VARCHAR(50) NOT NULL UNIQUE, -- поверю шпаргалке насчет длинны, строковый тип для строковых данных.
                                               origin_id INT NOT NULL REFERENCES car_shop.countries -- внешний ключ с типом одной размерности с SERIAL, указывает на страны.
);

CREATE TABLE IF NOT EXISTS car_shop.models ( -- Модели: наименование и усредненное потребление со ссылкой на бренд.
                                               id SERIAL PRIMARY KEY,
                                               name VARCHAR(65) NOT NULL, -- длинны с запасом для какого арабского гелика, который подсказал гугл. Строковый тип для строковых данных.
                                               brand_id INT NOT NULL REFERENCES car_shop.brands, -- внешний ключ с типом одной размерности с SERIAL, указывает на бренды.
                                               gasoline_consumption NUMERIC(4,2) CHECK ((gasoline_consumption > 0 AND gasoline_consumption <= 100) OR gasoline_consumption IS NULL) -- потребление топлива, по условиям не может быть трехзначным, но может быть дробным. Нумерик для повешенной точности.
);

CREATE TABLE IF NOT EXISTS car_shop.colors ( -- Отделил цвета для нормализации, уникальность для отсечения дубликатов.
                                               id SERIAL PRIMARY KEY,
                                               name VARCHAR(30) NOT NULL UNIQUE -- строковый тип для строковых данных, длинна по наитию.
);

CREATE TABLE IF NOT EXISTS car_shop.customers ( -- Клиенты
                                                  id SERIAL PRIMARY KEY,
                                                  first_name VARCHAR(50) NOT NULL, -- имя, взял с запасом, но не представляю как тут можно подобрать тип - и имя и фамилию можно взять выдуманную - нет источника данных для анализа.
                                                  last_name VARCHAR(50) NOT NULL, -- фамилия аналогично имени.
                                                  phone_number VARCHAR(25) NOT NULL -- номер телефона, 1 784 - код Сент Винцент и Гренадины и 10 цифр после, плюс доп код + плюс возможная модерация.
);

CREATE TABLE IF NOT EXISTS car_shop.sales ( -- Сделки, ссылаются на проданную машину и купившего клиента. Здесь содержится скидка, тк я не смог достоверно установить связь скидки с клиентом или авто, вынес по принципу скидка уникальная для сделки - как договорятся клиент и менеджер.
                                              id SERIAL PRIMARY KEY,
                                              model_id INT NOT NULL REFERENCES car_shop.models, -- внешний ключ с типом одной размерности с SERIAL, указывает на модели.
                                              color_id INT NOT NULL REFERENCES car_shop.colors, -- внешний ключ с типом одной размерности с SERIAL, указывает на цвета.
                                              price NUMERIC(9,2) NOT NULL, -- цена может содержать только сотые и не может быть больше семизначной суммы. Нумерик для повешенной точности.
                                              discount SMALLINT NOT NULL DEFAULT 0,
                                              customer_id INT NOT NULL REFERENCES car_shop.customers, -- внешний ключ с типом одной размерности с SERIAL, указывает на клиентов.
                                              date DATE NOT NULL
);

-- Заполнение сырых данных

COPY raw_data.sales
    FROM '/raw_data/cars.csv'
    WITH CSV HEADER NULL 'null';

-- Нормализация данных

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

-- Аналитические запросы

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
