COPY raw_data.sales
FROM '/raw_data/cars.csv'
WITH CSV HEADER NULL 'null';
