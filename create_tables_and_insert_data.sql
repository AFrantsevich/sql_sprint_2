CREATE TYPE cafe.restaurant_type AS ENUM
    ('coffee_shop', 'restaurant', 'bar', 'pizzeria');

CREATE TABLE cafe.menu(id SMALLSERIAL PRIMARY KEY,
                       menu jsonb UNIQUE NOT NULL);

CREATE TABLE cafe.restaurants
    (restaurant_uuid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
     name varchar(255) NOT NULL,
     location GEOMETRY(POINT) NOT NULL,
     type cafe.restaurant_type,
     menu INTEGER REFERENCES cafe.menu NOT NULL,
     CONSTRAINT unique_restaurant UNIQUE(name, location, menu));

CREATE TABLE cafe.managers
    (manager_uuid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
     first_name varchar(255) NOT NULL,
     last_name varchar(255) NOT NULL,
     middle_name varchar(255) DEFAULT NULL,
     phone varchar(255) NOT NULL,
     CONSTRAINT unique_manager UNIQUE(first_name, last_name, phone));

CREATE TABLE cafe.restaurant_manager_work_dates
    (restaurant_uuid UUID REFERENCES cafe.restaurants (restaurant_uuid) NOT NULL,
     manager_uuid UUID REFERENCES cafe.managers (manager_uuid) NOT NULL,
     PRIMARY KEY (restaurant_uuid, manager_uuid),
     date_start_work date NOT NULL DEFAULT current_date,
     date_end_work date
     );

CREATE TABLE cafe.sales
    (restaurant_uuid UUID REFERENCES cafe.restaurants (restaurant_uuid) NOT NULL,
     report_date date NOT NULL DEFAULT current_date,
     avg_check NUMERIC(10, 2),
     PRIMARY KEY (restaurant_uuid, report_date)
     );

INSERT INTO cafe.menu(menu)
SELECT menu
FROM raw_data.menu;

WITH
    menu AS (SELECT id, raw_m.cafe_name cafe_name
             FROM cafe.menu
             LEFT JOIN raw_data.menu raw_m
             USING (menu)),
    location AS (SELECT DISTINCT cafe_name,
                              CONCAT('POINT(', longitude,' ',  latitude, ')') point
              FROM raw_data.sales)
INSERT INTO cafe.restaurants(
    name,
    location,
    type,
    menu)
SELECT DISTINCT raw_data.sales.cafe_name,
    location.point,
    raw_data.sales.type::cafe.restaurant_type,
    menu.id
FROM raw_data.sales
JOIN menu USING(cafe_name)
JOIN location USING(cafe_name);

INSERT INTO cafe.managers(first_name,
                          middle_name,
                          last_name,
                          phone)
SELECT SPLIT_PART(manager, ' ', 1),
       SPLIT_PART(manager, ' ', 2),
       SPLIT_PART(manager, ' ', 3),
       manager_phone
FROM raw_data.sales
GROUP BY manager, manager_phone;

WITH
    work_dates AS (SELECT manager,
                   manager_phone,
                   cafe_name,
                   CONCAT (manager, ' ', manager_phone) field_to_compare,
                   MIN(report_date) date_start_work,
                   MAX(report_date) date_end_work
                   FROM raw_data.sales
                   GROUP BY manager, cafe_name, manager_phone),
    managers_for_join AS (SELECT CONCAT (first_name, ' ', middle_name, ' ', last_name, ' ', phone) field_to_compare,
                          manager_uuid
                          FROM cafe.managers)
/*Была версия джоинить по ФИО, предположим у нас могут быть два полных тезки,
следующая версия была джоинить по номеру телефона, предположим номер телефона был сперва у одного менеджера,
потом его передали другому. Поэтому появилась идея сделать ФИО + Номер.*/
INSERT INTO cafe.restaurant_manager_work_dates(
    restaurant_uuid,
    manager_uuid,
    date_start_work,
    date_end_work)
SELECT restaurants.restaurant_uuid,
       manager_uuid,
       date_start_work,
       date_end_work
FROM work_dates
LEFT JOIN managers_for_join USING (field_to_compare)
LEFT JOIN cafe.restaurants ON (cafe.restaurants.name = work_dates.cafe_name);

INSERT INTO cafe.sales(
    restaurant_uuid,
    report_date,
    avg_check)
SELECT r.restaurant_uuid,
       s.report_date,
       s.avg_check
FROM raw_data.sales s
LEFT JOIN cafe.restaurants r ON s.cafe_name = r.name;
