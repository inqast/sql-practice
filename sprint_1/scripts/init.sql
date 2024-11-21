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

