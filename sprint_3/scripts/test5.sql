BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT *
FROM employee_rate_history
ORDER BY from_date;

INSERT INTO employees (name, email, rate)
VALUES ('test', 'test', 1000);

SELECT *
FROM employee_rate_history
ORDER BY from_date;
ROLLBACK;

BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT *
FROM employee_rate_history
ORDER BY from_date;

UPDATE employees
SET rate = 1500
WHERE id = '4698dd76-9ad5-4d16-8772-90d30620fef2';

SELECT *
FROM employee_rate_history
ORDER BY from_date;
ROLLBACK;