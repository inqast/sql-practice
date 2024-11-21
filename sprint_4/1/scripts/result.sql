/*
1 задача
Причина: Таблица перегружена индексами, поддержка консистентности которых замедляет вставку.
Так же при вставке используется не самый эффективный метод выбора нового id заказа.
План: Проанализировать индексы по каким полям действительно необходимы - от остальных избавиться.
В приведенных для примера запроса данные фильтруются по order_id, order_dt, user_id
Создать последовательность для генерации order_id
*/
DROP INDEX IF EXISTS
    orders_city_id_idx,
    orders_device_type_city_id_idx,
    orders_device_type_idx,
    orders_discount_idx,
    orders_final_cost_idx,
    orders_total_cost_idx,
    orders_total_final_cost_discount_idx;

CREATE SEQUENCE IF NOT EXISTS orders_order_id_seq;
SELECT setval('orders_order_id_seq', (SELECT MAX(order_id) FROM orders)+1);
ALTER TABLE orders
    ALTER COLUMN order_id SET DEFAULT nextval('orders_order_id_seq'),
    ALTER COLUMN order_id SET NOT NULL;

INSERT INTO orders
(order_dt, user_id, device_type, city_id, total_cost, discount,
 final_cost)
SELECT current_timestamp,
       '329551a1-215d-43e6-baee-322f2467272d',
       'Mobile', 1, 1000.00, null, 1000.00;

/*
2 задача
Причина: Запрос перегружен преобразованиями данных, часть из них избыточна,
часть вытекает из не оптимально подобранных типов данных для таблицы.
План: Преобразовать типы в таблице в более подходящие для их обработки.
Так же можно добавить дополнительно функциональный индекс по дате рождения,
но не знаю стоит ли его поддержка свеч.
*/
ALTER TABLE users
    ALTER COLUMN user_id TYPE uuid USING user_id::text::uuid,
    ALTER COLUMN birth_date TYPE date USING to_date(birth_date::text, 'yyyy-mm-dd');

SELECT user_id, first_name, last_name,
       city_id, gender
FROM users
WHERE city_id = 4
  AND date_part('day', birth_date)
    = date_part('day', to_date('31-12-2023', 'dd-mm-yyyy'))
  AND date_part('month', birth_date)
    = date_part('month', to_date('31-12-2023', 'dd-mm-yyyy'));

/*
3 задача
Причина: Предположим в операции задействованы лишние таблицы.
Таблица order_status необходима для отслеживания истории движения заказа по статусам.
А вот связь таблиц payments и sales не очень понятна, данные в них дублируют друг друга и данные других таблиц.
План: (в проде я бы так не рискнул делать ни за какие деньги) Отказаться от таблицы sales
user_id можно не переносить тк он содержится в orders
sale_dt так же можно получить из status_dt статуса 2 для этого заказа
Удалять таблицу сразу не буду, тк гипотетически нужно было бы сделать рефакторинг все затронутых функций для работы с оплатами.
*/

CREATE OR REPLACE PROCEDURE add_payment(IN p_order_id bigint, IN p_sum_payment numeric)
    language plpgsql
as
$$BEGIN
    INSERT INTO order_statuses (order_id, status_id, status_dt)
    VALUES (p_order_id, 2, statement_timestamp());

    INSERT INTO payments (payment_id, order_id, payment_sum)
    VALUES (nextval('payments_payment_id_sq'), p_order_id, p_sum_payment);
END;$$;


/*
4 задача
Причина: Замедление вставки обычно связано с задержками на поддержание индексов.
Так же лог содержит избыточные данные
    datetime и log_date.
    log_id так же кажется бесполезным.
    не могу точно понять разницу между visitor_uuid и user_id, если от какого то из них можно отказаться - так же получится сократить нагрузку.

План: Если логи нужно выгребать и анализировать раз в квартал - можно пожертвовать индексами.
Так можно порезать избыточные данные.
*/

/*
5 задача
План: Тк данные не включают текущий день - это анализ исторических данных.
Удобно будет использовать материализованное представление и пересчитывать его раз в сутки.
*/
CREATE OR REPLACE FUNCTION get_preferences(
    p_from_age int,
    p_to_age int
)
RETURNS TABLE (day date, age text, spicy int, fish int, meat int)
LANGUAGE sql
AS $$
SELECT
    DATE_TRUNC('day', o.order_dt) as day,
    CONCAT(p_from_age::text, '-', p_to_age::text),
    (SUM(d.spicy)::numeric / COUNT(d.*)::numeric * 100)::INT,
    (SUM(d.fish)::numeric / COUNT(d.*)::numeric * 100)::INT,
    (SUM(d.meat)::numeric / COUNT(d.*)::numeric * 100)::INT
FROM users u
LEFT JOIN orders o ON (u.user_id = o.user_id)
LEFT JOIN order_items i ON (o.order_id = i.order_id)
LEFT JOIN dishes d ON (i.item = d.object_id)
WHERE
    DATE_TRUNC('day', o.order_dt) < CURRENT_DATE
    AND EXTRACT(year FROM AGE(current_date, u.birth_date)) BETWEEN p_from_age AND p_to_age-1
GROUP BY day;
$$;

CREATE MATERIALIZED VIEW preferences_by_age_group AS (
SELECT *
FROM
    (select * from get_preferences(0,20)) y
UNION
    (select * from get_preferences(20,30))
UNION
    (select * from get_preferences(30,40))
UNION
    (select * from get_preferences(40,100))
ORDER BY day, age
);