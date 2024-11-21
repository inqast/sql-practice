WITH
restaurants AS (
    SELECT DISTINCT
        cafe_name,
        type::cafe.restaurant_type,
        st_makepoint(longitude, latitude)::GEOGRAPHY AS location
    FROM raw_data.sales
)

INSERT INTO cafe.restaurants (name, location, restaurant_type, menu)
SELECT r.cafe_name, r.location, r.type, m.menu
FROM restaurants r
LEFT JOIN raw_data.menu m ON (r.cafe_name = m.cafe_name);

INSERT INTO cafe.managers (name, phone)
SELECT DISTINCT manager, manager_phone
FROM raw_data.sales;

INSERT INTO cafe.restaurant_manager_work_dates (restaurant_uuid, manager_uuid, start_date, end_date)
SELECT
    r.restaurant_uuid,
    m.manager_uuid,
    MIN(s.report_date),
    MAX(s.report_date)
FROM raw_data.sales s
    LEFT JOIN cafe.restaurants r ON (r.name = s.cafe_name)
    LEFT JOIN cafe.managers m ON (m.phone = s.manager_phone)
GROUP BY r.restaurant_uuid, m.manager_uuid;

INSERT INTO cafe.sales (restaurant_uuid, date, avg_check)
SELECT r.restaurant_uuid, s.report_date, s.avg_check
FROM raw_data.sales s
    LEFT JOIN cafe.restaurants r ON (r.name = s.cafe_name);