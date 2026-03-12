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

/* 1. С помощью запроса, использующего концепцию оконных функций, выведите накопленные суммы продаж билетов 
по q в каждом месяце. q = "неделям" */

SELECT * FROM ticket_flights;
SELECT * FROM bookings;
SELECT * FROM tickets;

WITH sales AS (
	SELECT
		date_trunc('month', b.book_date) AS month,
		date_trunc('week', b.book_date) AS week,
		SUM(tf.amount) AS week_amount
	FROM ticket_flights tf
	JOIN tickets t ON tf.ticket_no = t.ticket_no
	JOIN bookings b ON t.book_ref = b.book_ref
	GROUP BY month, week
)
SELECT
	month,
	week,
	week_amount,
	SUM(week_amount) OVER (PARTITION BY month ORDER BY week) AS cumulative_amount
FROM sales
ORDER BY month, week;

/* 2. С помощью запроса, использующего концепцию оконных функций, по каждой модели самолета, выполняющего рейсы, 
выведите ежедневное количество рейсов, накопленное количество рейсов, скользящее среднее количества рейсов для 
фрейма p (учитываем, что фрейм находится внутри раздела), относительное количество рейсов, приходящееся на весь 
рассматриваемый период полетов. p – предыдущая, текущая и 2 следующих строки */

SELECT * FROM flights;

WITH daily_flights AS (
	SELECT aircraft_code, scheduled_departure::date AS flight_date, COUNT(*) AS daily_count
	FROM flights
	GROUP BY aircraft_code, flight_date
)

SELECT aircraft_code, flight_date, daily_count,
	SUM(daily_count) OVER (PARTITION BY aircraft_code ORDER BY flight_date) AS cumulative_total,
	AVG(daily_count) OVER (
		PARTITION BY aircraft_code
		ORDER BY flight_date
		ROWS BETWEEN 1 PRECEDING AND 2 FOLLOWING -- Если строк не хватает, окно сужается до доступных 
	) AS moving_avg,
	daily_count / SUM(daily_count) OVER (PARTITION BY aircraft_code) AS relative_share,
	SUM(daily_count) OVER (PARTITION BY aircraft_code) AS total_by_model
FROM daily_flights
ORDER BY aircraft_code, flight_date;

/* 3. С помощью запроса, использующего концепцию оконных функций, вычислите ранги моделей самолетов по количеству 
пассажиров в неделю */

SELECT * FROM flights;
SELECT * FROM ticket_flights;

WITH weekly_passengers AS (
	SELECT date_trunc('week', f.scheduled_departure) AS week, f.aircraft_code, COUNT(tf.ticket_no) AS passengers
	FROM flights f
	JOIN ticket_flights tf ON f.flight_id = tf.flight_id
	GROUP BY week, f.aircraft_code
)

SELECT week, aircraft_code, passengers, RANK() OVER (PARTITION BY week ORDER BY passengers DESC) AS rank
FROM weekly_passengers
ORDER BY week, rank;

-- Упражнение 2 (блок)

/* 1. Увеличьте количество записей в таблице t в p раз, аналогично увеличению количества записей в таблице 
advertisement. Выполните подсчет строк в таблице t, используя выборки из нее. Вероятность включения строки 
в выборку в процентах = q. t = tickets, p=16, q=7 */

SELECT * FROM tickets;

DROP TABLE IF EXISTS tickets_x16;
CREATE TEMP TABLE tickets_x16 AS
SELECT t.*
FROM tickets t
CROSS JOIN generate_series(1, 16);

SELECT COUNT(*) AS sample_count_bernoulli FROM tickets_x16 TABLESAMPLE BERNOULLI(7);  --метод статистической выборки
SELECT COUNT(*) AS sample_count_random FROM tickets_x16 WHERE random() < 0.07;

/* 2. Придумайте и реализуйте запрос с латеральным подзапросом для ранее созданной таблицы комментариев чата 
(хранящей дерево комментариев), в соответствии со своим вариантом. ===//=== */

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


SELECT
	c.id,
	c.contentt AS comment_text,
	latest_reply.contentt AS latest_reply_text,
	latest_reply.created_at AS reply_date
FROM coment c

-- позволяет подзапросу справа обращаться к столбцам из таблиц, указанных слева
LEFT JOIN LATERAL (
	SELECT contentt, created_at
	FROM coment
	WHERE parent_id = c.id
	ORDER BY created_at DESC
	LIMIT 1
) latest_reply ON true
ORDER BY c.id;

/* 3. а) Напишите запрос, который для каждой модели самолета выводит количество мест q.
Используйте вариант с FILTER и вариант без FILTER (просто CASE WHEN). */

SELECT * FROM seats;

SELECT
	aircraft_code,
	COUNT(*) FILTER (WHERE fare_conditions = 'Economy') AS economy_seats,
	COUNT(*) FILTER (WHERE fare_conditions = 'Comfort') AS comfort_seats
FROM seats
GROUP BY aircraft_code
ORDER BY aircraft_code;

SELECT
	aircraft_code,
	SUM(CASE WHEN fare_conditions = 'Economy' THEN 1 ELSE 0 END) AS economy_seats,
	SUM(CASE WHEN fare_conditions = 'Comfort' THEN 1 ELSE 0 END) AS comfort_seats
FROM seats
GROUP BY aircraft_code
ORDER BY aircraft_code;

/* б) Напишите запрос, который находит p номер билета для каждого бронирования
(используйте DISTINCT ON, а также альтернативные варианты) б) p = “первый с единицей в начале”. */

SELECT * FROM tickets;

SELECT DISTINCT ON (book_ref) book_ref, ticket_no FROM tickets WHERE ticket_no LIKE '0005432_1%'
ORDER BY book_ref, ticket_no;

WITH ranked AS (
	SELECT book_ref, ticket_no, ROW_NUMBER() OVER (PARTITION BY book_ref ORDER BY ticket_no) AS rn
	FROM tickets WHERE ticket_no LIKE '0005432_1%'
)

SELECT book_ref, ticket_no FROM ranked WHERE rn = 1
ORDER BY book_ref;

/* 4. Напишите запрос, который возвращает ранг числа x в множестве, которое начинается числом a, ограничено 
числом b, шаг между числами – h. Выведите все числа этого множества. x = 76, a = 50, b = 5000, h = 10 */

WITH numbers AS (SELECT generate_series(50, 5000, 10) AS num), 
	numbered AS (SELECT num, ROW_NUMBER() OVER (ORDER BY num) AS rankk FROM numbers)

SELECT num, rankk, (SELECT rankk FROM numbered WHERE num = 76) AS rank_of_76
FROM numbered
ORDER BY num;

/* 5. Напишите запрос о распределении количества билетов по рейсам для p и q процентилей. p = 14, q = 78 */

SELECT * FROM ticket_flights;

WITH per_flight AS (
	SELECT flight_id, COUNT(*) AS tickets_count
	FROM ticket_flights
	GROUP BY flight_id
)

SELECT
	percentile_cont(0.14) WITHIN GROUP (ORDER BY tickets_count) AS p14,
	percentile_cont(0.78) WITHIN GROUP (ORDER BY tickets_count) AS p78
FROM per_flight;

/* 6. Общее задание: Используя ROLLUP, GROUPING SETS, CUBE (напишите одни и те же запросы разными способами) 
вычислите суммы продаж билетов на авиарейсы по моделям самолетов, дням, месяцам и сумму продаж за весь период. */

SELECT * FROM ticket_flights;
SELECT * FROM flights;

DROP TABLE IF EXISTS sales_temp;

CREATE TEMP TABLE sales_temp AS
SELECT
    f.aircraft_code,
    f.scheduled_departure::date AS day,
    date_trunc('month', f.scheduled_departure)::date AS month,
    tf.amount
FROM ticket_flights tf
JOIN flights f ON tf.flight_id = f.flight_id;

-- ROLLUP
SELECT aircraft_code, day, month, SUM(amount) AS total_sales
FROM sales_temp
GROUP BY ROLLUP (aircraft_code, day, month)
ORDER BY aircraft_code, day, month;

-- GROUPING SETS
SELECT aircraft_code, day, month, SUM(amount) AS total_sales
FROM sales_temp
GROUP BY GROUPING SETS (
    (aircraft_code, day, month),
    (aircraft_code, day),
    (aircraft_code, month),
    (aircraft_code),
    (day, month),
    (day),
    (month),
    ()
)
ORDER BY aircraft_code, day, month;

-- CUBE
SELECT aircraft_code, day, month, SUM(amount) AS total_sales
FROM sales_temp
GROUP BY CUBE (aircraft_code, day, month)
ORDER BY aircraft_code, day, month;