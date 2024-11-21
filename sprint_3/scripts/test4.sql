BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT *
FROM logs
WHERE project_id IN ('2dfffa75-7cd9-4426-922c-95046f3d06a0')
ORDER BY created_at;

CALL log_work(
        'b15bb4c0-1ee1-49a9-bc58-25a014eebe36',
        '2dfffa75-7cd9-4426-922c-95046f3d06a0',
        current_date,
        3
     );

SELECT *
FROM logs
WHERE project_id IN ('2dfffa75-7cd9-4426-922c-95046f3d06a0')
ORDER BY created_at;
ROLLBACK;

BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT *
FROM logs
WHERE project_id IN ('4abb5b99-3889-4c20-a575-e65886f266f9')
ORDER BY created_at;

CALL log_work(
        'b15bb4c0-1ee1-49a9-bc58-25a014eebe36',
        '4abb5b99-3889-4c20-a575-e65886f266f9',
        current_date+1,
        3
     );

SELECT *
FROM logs
WHERE project_id IN ('4abb5b99-3889-4c20-a575-e65886f266f9')
ORDER BY created_at;
ROLLBACK;