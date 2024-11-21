SELECT auto, gasoline_consumption, price, date, person, phone, discount, brand_origin
FROM raw_data.sales
EXCEPT
SELECT
    CONCAT(b.name, ' ', m.name, ', ', color.name) as auto,
    m.gasoline_consumption,
    (car.price/100 * (100-s.discount))::numeric(9,2) as price,
    s.date,
    CONCAT(customer.first_name, ' ', customer.last_name) as person,
    customer.phone_number as phone,
    s.discount,
    country.name as brand_origin
FROM car_shop.sales s
LEFT JOIN car_shop.customers customer on customer.id = s.customer_id
LEFT JOIN car_shop.cars car on car.id = s.car_id
LEFT JOIN car_shop.models m on m.id = car.model_id
Left Join car_shop.colors color on color.id = car.color_id
LEFT JOIN car_shop.brands b on b.id = m.brand_id
LEFT JOIN car_shop.countries country on country.id = b.origin_id
ORDER BY auto;