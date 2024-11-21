CREATE OR REPLACE FUNCTION scale_value(
    value integer,
    rate integer
)
RETURNS integer
LANGUAGE plpgsql
AS $$
BEGIN
    return (value * (1+(rate)::numeric(5,2)/100))::integer;
END;
$$;

CREATE OR REPLACE PROCEDURE update_employees_rate(
    p_input json
)
LANGUAGE plpgsql
AS $$
DECLARE
    _elem json;
    _employee_id uuid;
    _rate integer;
BEGIN
    FOREACH _elem IN ARRAY (ARRAY (SELECT json_array_elements(p_input))) LOOP
        _employee_id = (_elem->>'employee_id')::uuid;

        _rate = (SELECT rate
        FROM employees
        WHERE id = _employee_id);

        _rate = scale_value(_rate, (_elem->>'rate_change')::integer);

        IF _rate < 500 THEN
            _rate = 500;
        END IF;

        UPDATE employees
        SET rate = _rate
        WHERE id = _employee_id;
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE indexing_salary(
    p_indexing_percent integer
)
LANGUAGE plpgsql
AS $$
DECLARE
    _avg_salary integer;
BEGIN
    SELECT AVG(rate)::integer
    INTO STRICT _avg_salary
    FROM employees;

    UPDATE employees
    SET rate = CASE
        WHEN rate < _avg_salary THEN
            scale_value(rate,p_indexing_percent+2)
        ELSE
            scale_value(rate,p_indexing_percent)
        END;
END;
$$;

CREATE OR REPLACE PROCEDURE close_project(
    p_project_id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE
    _is_active boolean;
    _estimated_time integer;
    _actual_time integer;
    _workers_count integer;
    _bonus_time_by_worker integer;
    _r record;
BEGIN
    SELECT is_active, estimated_time
    INTO _is_active, _estimated_time
    FROM projects
    WHERE id = p_project_id;

    if NOT _is_active THEN
        RAISE EXCEPTION 'already closed';
    END IF;

    UPDATE projects
    SET is_active = false
    WHERE id = p_project_id;

    IF _estimated_time IS NULL THEN
        RETURN;
    END IF;

    SELECT SUM(work_hours), COUNT(DISTINCT employee_id)
    INTO _actual_time, _workers_count
    FROM logs
    WHERE project_id = p_project_id;

    IF _actual_time = 0 OR _estimated_time - _actual_time <= 0 THEN
        RETURN;
    END IF;

    _bonus_time_by_worker = ((_estimated_time - _actual_time)::numeric * 0.75 / _workers_count::numeric)::integer;
    IF _bonus_time_by_worker > 16 THEN
        _bonus_time_by_worker = 16;
    END IF;

    FOR _r IN (SELECT DISTINCT employee_id
        FROM logs
        WHERE project_id = p_project_id) LOOP
        INSERT INTO logs (employee_id, project_id, work_date, work_hours)
        VALUES (_r.employee_id, p_project_id, current_date, _bonus_time_by_worker);
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE log_work(
    p_employee_id uuid,
    p_project_id uuid,
    p_date date,
    p_work_hours integer
)
LANGUAGE plpgsql
AS $$
DECLARE
    _is_active bool;
    _review_required bool = false;
BEGIN
    IF p_work_hours < 1 OR p_work_hours > 24 THEN
        RAISE EXCEPTION 'Invalid work hours';
    END IF;

    SELECT is_active
    INTO _is_active
    FROM projects
    WHERE id = p_project_id;

    IF NOT _is_active THEN
        RAISE EXCEPTION 'Project closed';
    END IF;

    IF p_work_hours > 16 OR
       current_date < p_date OR
       current_date - interval '1 week' <= p_date
    THEN
        _review_required = true;
    END IF;

    INSERT INTO logs (employee_id, project_id, work_date, work_hours, required_review)
    VALUES (p_employee_id, p_project_id, p_date, p_work_hours, _review_required);
END;
$$;

CREATE TABLE IF NOT EXISTS employee_rate_history (
    ID SERIAL PRIMARY KEY,
    employee_id uuid,
    rate integer,
    from_date date
);

INSERT INTO employee_rate_history (employee_id, rate, from_date)
SELECT id, rate, '2020-12-26'::date
FROM employees;

CREATE OR REPLACE FUNCTION save_employee_rate_history()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO employee_rate_history (employee_id, rate, from_date)
    VALUES (NEW.id, NEW.rate, current_date);

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER change_employee_rate
AFTER INSERT OR UPDATE ON employees
FOR EACH ROW
EXECUTE FUNCTION save_employee_rate_history();

CREATE OR REPLACE FUNCTION best_project_workers(
    p_project_id uuid
)
RETURNS TABLE (name text, hours_count int)
LANGUAGE sql
AS $$
    SELECT e.name, SUM(l.work_hours) as hours_count
    FROM logs l
    LEFT JOIN employees e ON (l.employee_id = e.id)
    WHERE l.project_id = p_project_id
    GROUP BY l.project_id, e.id, e.name
    ORDER BY hours_count, COUNT(l.id) DESC
    LIMIT 3;
$$;

CREATE OR REPLACE FUNCTION calculate_month_salary(
    p_start_date date,
    p_end_date date
)
RETURNS TABLE (id uuid, employee text, worked_hours integer, salary integer)
LANGUAGE sql
AS $$
    SELECT
        e.id,
        e.name,
        SUM(l.work_hours) as worked_hours,
        CASE
        WHEN SUM(l.work_hours) > 160 THEN
            (SUM(l.work_hours) * e.rate)+((SUM(l.work_hours)-160) * e.rate::numeric * 1.25)::integer
        ELSE
            SUM(l.work_hours) * e.rate
        END as salary
    FROM logs l
    LEFT JOIN employees e ON (l.employee_id = e.id)
    WHERE l.work_date BETWEEN p_start_date AND p_end_date
    AND NOT l.is_paid AND NOT l.required_review
    GROUP BY e.id, e.name;
$$;
