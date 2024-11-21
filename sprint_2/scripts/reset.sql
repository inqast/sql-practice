DROP TABLE IF EXISTS cafe.restaurants CASCADE ;
DROP TABLE IF EXISTS cafe.managers CASCADE;
DROP TABLE IF EXISTS cafe.restaurant_manager_work_dates CASCADE;
DROP TABLE IF EXISTS cafe.sales CASCADE;
DROP MATERIALIZED VIEW IF EXISTS cafe.v_avg_check;
DROP TYPE IF EXISTS cafe.restaurant_type;