BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT rate
FROM employees
WHERE id IN ('181b2307-9e97-4cde-8b9e-b2d9d3d79f09', '342eca8b-d6d6-424d-9499-a498cb7cbf89', '3fad62fa-3035-46a8-a91f-2864d6304cc5', '4698dd76-9ad5-4d16-8772-90d30620fef2')
ORDER BY id;

CALL update_employees_rate(
     '[
       {"employee_id": "181b2307-9e97-4cde-8b9e-b2d9d3d79f09", "rate_change": -100},
       {"employee_id": "342eca8b-d6d6-424d-9499-a498cb7cbf89", "rate_change": 50},
       {"employee_id": "3fad62fa-3035-46a8-a91f-2864d6304cc5", "rate_change": -50},
       {"employee_id": "4698dd76-9ad5-4d16-8772-90d30620fef2", "rate_change": 3}
     ]'::json
     );

SELECT rate
FROM employees
WHERE id IN ('181b2307-9e97-4cde-8b9e-b2d9d3d79f09', '342eca8b-d6d6-424d-9499-a498cb7cbf89', '3fad62fa-3035-46a8-a91f-2864d6304cc5', '4698dd76-9ad5-4d16-8772-90d30620fef2')
ORDER BY id;
ROLLBACK;
