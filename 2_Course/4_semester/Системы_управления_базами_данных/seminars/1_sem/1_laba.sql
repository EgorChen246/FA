-- Вариант 8

SELECT * FROM aircrafts_data;
SELECT * FROM airports_data;
SELECT * FROM boarding_passes;
SELECT * FROM bookings;
SELECT * FROM flights;
SELECT * FROM seats;
SELECT * FROM ticket_flights;
SELECT * FROM tickets;

-- Упражнение 1 (блок)

/* 1. Напишите запрос на основе использования подзапросов, который выявляет направления, на которые было продано: от 20 до 500 билетов */

SELECT * FROM flights;
SELECT * FROM ticket_flights;

SELECT DISTINCT f.departure_airport, f.arrival_airport FROM flights f
WHERE f.flight_id IN (SELECT tf.flight_id FROM ticket_flights tf GROUP BY tf.flight_id HAVING COUNT(tf.ticket_no) BETWEEN 20 AND 500)
ORDER BY departure_airport, arrival_airport;

/* 2. Напишите запрос на основе использования подзапросов, который подсчитывает количество операций бронирования, 
в которых общая сумма не превышает q от p величины по всей выборке. q = 0.45, p = средней */

SELECT * FROM bookings;

SELECT COUNT(*) AS bookings_count FROM bookings
WHERE total_amount <= 0.45 * (SELECT AVG(total_amount) FROM bookings);

/* 3. Напишите запрос на основе использования подзапросов, который выводит для каждой модели самолета количество мест класса business,
количество мест класса comfort и количество мест класса economy, которые занимали более p пассажиров в q-м месяце. p = 50000, q = 8 */

SELECT * FROM seats;
SELECT * FROM aircrafts_data;

SELECT DISTINCT
    ad.aircraft_code,
    ad.model ->> 'ru' AS model_name,
    
    (SELECT COUNT(*) FROM ticket_flights tf JOIN flights f ON tf.flight_id = f.flight_id
	WHERE f.aircraft_code = ad.aircraft_code AND EXTRACT(MONTH FROM f.scheduled_departure) = 8 AND tf.fare_conditions = 'Business'
) AS business_passengers,
    
    (SELECT COUNT(*) FROM ticket_flights tf JOIN flights f ON tf.flight_id = f.flight_id
     WHERE f.aircraft_code = ad.aircraft_code AND EXTRACT(MONTH FROM f.scheduled_departure) = 8 AND tf.fare_conditions = 'Comfort'
) AS comfort_passengers,
    
    (SELECT COUNT(*) FROM ticket_flights tf JOIN flights f ON tf.flight_id = f.flight_id
     WHERE f.aircraft_code = ad.aircraft_code AND EXTRACT(MONTH FROM f.scheduled_departure) = 8 AND tf.fare_conditions = 'Economy'
) AS economy_passengers

FROM aircrafts_data ad

WHERE
    (SELECT COUNT(*) FROM ticket_flights tf JOIN flights f ON tf.flight_id = f.flight_id
     WHERE f.aircraft_code = ad.aircraft_code AND EXTRACT(MONTH FROM f.scheduled_departure) = 8 AND tf.fare_conditions = 'Business') > 50000  
	OR
    (SELECT COUNT(*) FROM ticket_flights tf JOIN flights f ON tf.flight_id = f.flight_id
     WHERE f.aircraft_code = ad.aircraft_code AND EXTRACT(MONTH FROM f.scheduled_departure) = 8 AND tf.fare_conditions = 'Comfort') > 50000
    OR
    (SELECT COUNT(*) FROM ticket_flights tf JOIN flights f ON tf.flight_id = f.flight_id
     WHERE f.aircraft_code = ad.aircraft_code AND EXTRACT(MONTH FROM f.scheduled_departure) = 8 AND tf.fare_conditions = 'Economy') > 50000
ORDER BY ad.aircraft_code;

/* 4. Напишите запрос на основе использования подзапросов, который позволяет получить перечень аэропортов в тех городах (город, код
аэропорта, название аэропорта), в которых больше q аэропортов. q = 1 */

SELECT * FROM airports_data;

SELECT city ->> 'ru' AS city_name, airport_code, airport_name ->> 'ru' AS airport_name FROM airports_data
WHERE city ->> 'ru' IN (SELECT city ->> 'ru' FROM airports_data GROUP BY city HAVING COUNT(airport_code) > 1)
ORDER BY city_name, airport_code;

/* 5. Придумайте и напишите по одному запросу для каждого выражения подзапроса из множества w к базе данных об авиаперевозках. Запросы у
разных студентов не должны повторяться. w = {IN, SOME, ALL} */

SELECT * FROM flights;
SELECT * FROM airports_data;
SELECT * FROM ticket_flights;

-- IN (рейсы из мск)
SELECT flight_id, flight_no, departure_airport, scheduled_departure FROM flights
WHERE departure_airport IN (SELECT airport_code FROM airports_data WHERE city ->> 'ru' = 'Москва')
LIMIT 10;


-- SOME (фамилии совпадают на рейсе 306)
SELECT passenger_name FROM tickets
WHERE passenger_name = SOME (SELECT t.passenger_name FROM ticket_flights tf JOIN tickets t ON tf.ticket_no = t.ticket_no
    WHERE tf.flight_id = 306);


-- ALL (стоимость ниже и из DME)
SELECT ticket_no, amount FROM ticket_flights
WHERE amount < ALL (SELECT tf.amount FROM ticket_flights tf JOIN flights f ON tf.flight_id = f.flight_id 
	WHERE f.departure_airport = 'DME')
LIMIT 10;



-- Упражнение 2 (блок)

/* 1. Напишите запрос на основе CTE, который ищет в базе перелеты, совершенные после даты p (день.месяц), и выводит по
ним информацию о пассажирах, которые летели q-классом. p=17.07, q=Economy */

SELECT * FROM flights;
SELECT * FROM ticket_flights;
SELECT * FROM tickets;

WITH flights_after_july AS (SELECT flight_id FROM flights WHERE scheduled_departure::date > '2017-07-17')

SELECT
	t.passenger_name,
	t.ticket_no,
	f.flight_id,
	f.flight_no,
	f.scheduled_departure
FROM flights f

JOIN ticket_flights tf ON f.flight_id = tf.flight_id
JOIN tickets t ON tf.ticket_no = t.ticket_no WHERE f.flight_id IN (SELECT flight_id FROM flights_after_july) AND tf.fare_conditions = 'Economy'
ORDER BY f.scheduled_departure
LIMIT 50;

/* 2. Напишите запрос на основе CTE, который ищет максимальное количество пассажиров, совершивших минимальное количество перелетов 
в месяце q, в рейсах, совершенных из городов, название которые начинается с буквы p. q = 8, p = «С» */

SELECT * FROM flights;
SELECT * FROM airports_data;
SELECT * FROM ticket_flights;

-- Перелёты в августе из городов на 'С'
WITH august_flights_from_cities AS (
	SELECT
		f.flight_id,
		tf.ticket_no,
		f.departure_airport,
		a.city ->> 'ru' AS city_name
	FROM flights f

	JOIN airports_data a ON f.departure_airport = a.airport_code
	JOIN ticket_flights tf ON f.flight_id = tf.flight_id
	WHERE EXTRACT(MONTH FROM f.scheduled_departure) = 8 AND a.city ->> 'ru' LIKE 'С%'
),

-- Кол-во перелётов на пассажира
passenger_flight_counts AS (SELECT ticket_no, COUNT(*) AS flight_count FROM august_flights_from_cities GROUP BY ticket_no),

-- Мин кол-во перелётов
min_flight_count AS (SELECT MIN(flight_count) AS min_count FROM passenger_flight_counts)

-- Кол-во пассажиров с мин числом перелётов
SELECT COUNT(*) AS passengers_with_min_flights FROM passenger_flight_counts WHERE flight_count = (SELECT min_count FROM min_flight_count);


/* 3. Реализуйте рекурсивный запрос для вычисления значения выражения. Сумма семи величин n*(n + 3) при начальном n0= 1, с шагом 3: n1 = 4 и т.д. */

WITH RECURSIVE
series AS (
	-- генерируем начальную строку
	SELECT 1 AS n, 1 * (1 + 3) AS term_value, 1 AS step 
	UNION ALL
	-- рекурсия
	SELECT n + 3, (n + 3) * (n + 3 + 3), step + 1 FROM series WHERE step < 7
)
SELECT SUM(term_value) AS total_sum
FROM series;

/* 4. Выполните с помощью рекурсивных запросов обходы созданного дерева комментариев ( как создать - см. далее) в
глубину и ширину, сделайте скриншоты запросов и результатов. У студентов результаты этой задачи не должны повторяться. 
Создайте таблицу, в которой будут храниться комментарии чата, имеющие иерархическую структуру: каждый комментарий может иметь 
до пяти потомков. Заполните таблицу выдуманными данными, в таблице должно быть: как в варианте 2 – по структуре, не по содержанию! */

DROP TABLE IF EXISTS coment CASCADE;

CREATE TEMP TABLE coment (
	id SERIAL PRIMARY KEY,
	parent_id INT REFERENCES coment(id),
	author VARCHAR(100),
	contentt TEXT,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO coment (parent_id, author, contentt) VALUES
(NULL, 'User1', 'Корневой комментарий 1'),
(NULL, 'User2', 'Корневой комментарий 2'),
(1, 'User3', 'Ответ на корневой 1'),
(1, 'User4', 'Ещё ответ на корневой 1'),
(3, 'User5', 'Ответ на ответ (глубина 2)'),
(2, 'User6', 'Ответ на корневой 2');

SELECT * FROM coment;

-- DFS
WITH RECURSIVE coments_depth AS (
	SELECT
		id,
		parent_id,
		author,
		contentt,
		0 AS level,
		ARRAY[id] AS path
	FROM coment
	WHERE parent_id IS NULL

	UNION ALL

	SELECT
		c.id,
		c.parent_id,
		c.author,
		c.contentt,
		cd.level + 1,
		cd.path || c.id
	FROM coment c
	JOIN coments_depth cd ON c.parent_id = cd.id
)
SELECT
	level,
	repeat('  ', level) || author || ': ' || contentt AS comment_tree
FROM coments_depth
ORDER BY path;

-- BFS
WITH RECURSIVE comments_breadth AS (
	SELECT
		id,
		parent_id,
		author,
		contentt,
		0 AS level,
		id AS order_key
	FROM coment
	WHERE parent_id IS NULL

	UNION ALL

	SELECT
		c.id,
		c.parent_id,
		c.author,
		c.contentt,
		cb.level + 1,
		cb.order_key
	FROM coment c
	JOIN comments_breadth cb ON c.parent_id = cb.id
)
SELECT
	level,
	repeat('  ', level) || author || ': ' || contentt AS comment_tree
FROM comments_breadth
ORDER BY order_key, level;


-- Упражнение 3 (блок)

/* 1. Создайте обычное представление на основе запроса, включающего внутреннее соединение хотя бы двух таблиц (придумайте
запрос). В запросе (где-либо) должен присутствовать номер Вашего варианта. */

SELECT * FROM tickets;
SELECT * FROM ticket_flights;

DROP VIEW IF EXISTS passenger_flights_august CASCADE;

CREATE VIEW passenger_flights_august AS
SELECT
	t.passenger_name,
	t.ticket_no,
	f.flight_no,
	f.scheduled_departure,
	tf.fare_conditions
FROM tickets t
JOIN ticket_flights tf ON t.ticket_no = tf.ticket_no
JOIN flights f ON tf.flight_id = f.flight_id
WHERE EXTRACT(MONTH FROM f.scheduled_departure) = 8;  -- август

SELECT * FROM passenger_flights_august LIMIT 10;

/* 2. Создайте пустое материализованное представление на основе любого запроса к БД. Выполните запрос для заполнения этого
представления данными. В запросе (где-либо) должен присутствовать номер Вашего варианта.  */

DROP MATERIALIZED VIEW IF EXISTS daily_bookings_august CASCADE;

CREATE MATERIALIZED VIEW daily_bookings_august AS
SELECT
	book_date::date AS booking_day,
	COUNT(*) AS bookings_count,
	SUM(total_amount) AS daily_total
FROM bookings
WHERE EXTRACT(MONTH FROM book_date) = 8   -- август
GROUP BY booking_day
WITH NO DATA;

REFRESH MATERIALIZED VIEW daily_bookings_august;

SELECT * FROM daily_bookings_august ORDER BY booking_day;