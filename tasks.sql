--TASK 1
CREATE VIEW top_3_restaurants_by_category AS
    SELECT top_check.name, top_check.type, top_check.avg_check
    FROM (SELECT ROUND(AVG(avg_check), 2) avg_check,
                      name,
                      type,
                      ROW_NUMBER() OVER (PARTITION BY type ORDER BY AVG(avg_check) DESC)
                      FROM cafe.sales
                      LEFT JOIN cafe.restaurants USING (restaurant_uuid)
                      GROUP BY type, name) AS top_check
    WHERE row_number in (1, 2, 3);

--TASK 2
SELECT sales_by_year.year_avg_check, name, type, sales_by_year.avg_check_prev_year,
       ROUND(((sales_by_year.avg_check_cur_year - sales_by_year.avg_check_prev_year)
                / sales_by_year.avg_check_prev_year * 100), 2) AS "changed %"
FROM (SELECT avg_check_by_year.*,
      LAG(avg_check_by_year.avg_check_cur_year, 1) OVER (
          PARTITION BY avg_check_by_year.restaurant_uuid ORDER BY avg_check_by_year.year_avg_check
          ) avg_check_prev_year
      FROM (
          SELECT EXTRACT(YEAR FROM report_date) year_avg_check,
                 restaurant_uuid,
                 ROUND(AVG(avg_check), 2) avg_check_cur_year
          FROM cafe.sales
          WHERE EXTRACT(YEAR FROM report_date) != 2023
          GROUP BY (EXTRACT(YEAR FROM report_date)), restaurant_uuid
           ) AS avg_check_by_year
      ) AS sales_by_year
LEFT JOIN cafe.restaurants USING (restaurant_uuid);

--TASK 3
SELECT name, max_managers_change.count
FROM (SELECT restaurant_uuid, COUNT(DISTINCT manager_uuid)
      FROM cafe.restaurant_manager_work_dates
      GROUP BY restaurant_uuid
      ORDER BY count DESC
      LIMIT 3) AS max_managers_change
LEFT JOIN cafe.restaurants USING (restaurant_uuid);

--TASK 4
SELECT amount,
       name
FROM(
    SELECT pizza.id, COUNT(pizza.jsonb_object_keys) amount,
           RANK() OVER(ORDER BY COUNT(pizza.jsonb_object_keys) DESC)
    FROM (SELECT id, jsonb_object_keys(menu::jsonb -> 'Пицца')
          FROM cafe.menu) AS pizza
    GROUP BY pizza.id
    ) AS m
LEFT JOIN cafe.restaurants ON menu = m.id
WHERE rank = 1;

--TASK 5
SELECT r.name, 'Пицца' type, p.pizza_name, p.price FROM (
                SELECT m_p_pizza.*, MAX(m_p_pizza.price::int) OVER(PARTITION BY m_p_pizza.id) AS max_price
                FROM (
                    SELECT p_menu.id, (jsonb_each(p_menu.pizza)).key pizza_name, (jsonb_each(p_menu.pizza)).value price
                    FROM (SELECT id, menu::jsonb -> 'Пицца' AS pizza FROM cafe.menu) AS p_menu
                    ) AS m_p_pizza
               ) AS p
LEFT JOIN cafe.restaurants r ON r.menu = p.id
WHERE p.price::int = p.max_price::int
ORDER BY p.price DESC;

--TASK 6
SELECT r.name restaurants_1,
       tmp.name restaurants_2,
       ROUND(ST_Distance(r.location::geography, tmp.location::geography)) distance
FROM cafe.restaurants r
CROSS JOIN cafe.restaurants tmp
WHERE r.type = tmp.type AND ROUND(ST_Distance(r.location::geography, tmp.location::geography)) != 0
ORDER BY distance
LIMIT 1;

--TASK 7
(SELECT COUNT(r.name), d.district_name FROM cafe.restaurants AS r
LEFT JOIN cafe.districts AS d ON ST_Covers(d.district_geom, r.location::geography)
GROUP BY district_name
ORDER BY count DESC
LIMIT 1)
UNION
(SELECT COUNT(r.name), d.district_name FROM cafe.restaurants AS r
LEFT JOIN cafe.districts AS d ON ST_Covers(d.district_geom, r.location::geography)
GROUP BY district_name
ORDER BY count
LIMIT 1)
ORDER BY count DESC;
