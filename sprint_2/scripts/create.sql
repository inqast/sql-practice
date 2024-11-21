CREATE TYPE cafe.restaurant_type AS ENUM
    ('coffee_shop', 'restaurant', 'bar', 'pizzeria');

CREATE TABLE IF NOT EXISTS cafe.restaurants (
    restaurant_uuid UUID PRIMARY KEY DEFAULT GEN_RANDOM_UUID(),
    name VARCHAR(50) UNIQUE NOT NULL,
    location GEOGRAPHY(POINT) NOT NULL,
    restaurant_type  cafe.restaurant_type NOT NULL,
    menu jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS cafe.managers (
    manager_uuid UUID PRIMARY KEY DEFAULT GEN_RANDOM_UUID(),
    name VARCHAR(50) NOT NULL,
    phone VARCHAR(50) UNIQUE
);

CREATE TABLE IF NOT EXISTS cafe.restaurant_manager_work_dates (
    restaurant_uuid UUID,
    manager_uuid UUID,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    PRIMARY KEY (restaurant_uuid, manager_uuid)
);

CREATE TABLE IF NOT EXISTS cafe.sales (
    restaurant_uuid UUID,
    date DATE,
    avg_check NUMERIC(6, 2) NOT NULL,
    PRIMARY KEY (restaurant_uuid, date)
);

