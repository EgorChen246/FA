-- Задание 19-20 семинар
-- Вариант 1 (17 вариант по списку)

SELECT * FROM aircrafts_data;
SELECT * FROM airports_data;
SELECT * FROM boarding_passes;
SELECT * FROM bookings;
SELECT * FROM flights;
SELECT * FROM seats;
SELECT * FROM ticket_flights;
SELECT * FROM tickets;


-- 1. Проверьте, выполняется ли параллельно запрос, вычисляющий суммарную стоимость билетов, каждый из которых дешевле 5000. 

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT SUM(amount) FROM ticket_flights WHERE amount < 5000;

-- Finalize Aggregate – итоговая сумма
-- Gather – ведущий процесс собирает результаты от рабочих процессов
-- Partial Aggregate – каждый рабочий процесс вычисляет частичную сумму для своей порции строк
-- Parallel Seq Scan – таблица сканируется параллельно, каждый процесс читает свою часть блоков



-- 2. Запрос через CTE с MATERIALIZED (последовательное выполнение)

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
WITH cte AS MATERIALIZED (SELECT amount FROM ticket_flights WHERE amount < 5000)
SELECT SUM(amount) FROM cte;

-- MATERIALIZED заставляет планировщик выполнить CTE отдельно и сохранить результат во временной таблице
-- Внешний запрос читает эту временную таблицу (CTE Scan)
-- Временные таблицы не поддерживают параллельное сканирование



-- 3. Два способа найти максимальную цену билета 

-- Способ 1: агрегатная функция MAX (Метод последовательного сканирования. Читается вся таблица (миллионы строк))
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT MAX(amount) FROM ticket_flights;

-- Способ 2: сортировка и LIMIT (полное сканирование + сортировка всей таблицы)
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT amount FROM ticket_flights ORDER BY amount DESC LIMIT 1;

-- Создаем индекс
CREATE INDEX IF NOT EXISTS idx_ticket_flights_amount ON ticket_flights (amount);

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT MAX(amount) FROM ticket_flights;

-- Теперь план: Result - Limit - Index Only Scan Backward (очень быстро)

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT amount FROM ticket_flights ORDER BY amount DESC LIMIT 1;

-- План: Limit - Index Only Scan Backward



-- 4. Include-индекс для таблицы flights
-- Создаём уникальный include-индекс по flight_id с неключевым столбцом status
CREATE UNIQUE INDEX flights_include_idx ON flights (flight_id) INCLUDE (status);

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT flight_id, status FROM flights WHERE flight_id = 12345;
-- Проверяем: Index Only Scan using flights_include_idx

BEGIN;
ALTER TABLE flights DROP CONSTRAINT flights_pkey CASCADE;  -- Удаляем старый ПК с каскадным удалением ВК
ALTER TABLE flights ADD CONSTRAINT flights_pkey PRIMARY KEY USING INDEX flights_include_idx;  -- Добавляем новый ПК, используя созданный индекс
ALTER TABLE ticket_flights ADD CONSTRAINT ticket_flights_flight_id_fkey -- Восстанавливаем ВК из ticket_flights (если был удалён)
  FOREIGN KEY (flight_id) REFERENCES flights (flight_id);
COMMIT;

-- Проверяем, что ПК теперь использует include-индекс
SELECT indexname FROM pg_indexes WHERE tablename = 'flights' AND indexname = 'flights_include_idx';



-- 5. Запрос о перелётах стоимостью более 150 000 руб (последовательное сканирование)
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING ON)
SELECT * FROM ticket_flights WHERE amount > 150000;

SET enable_seqscan = off;  -- Запрещаем последовательное сканирование

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING ON)
SELECT * FROM ticket_flights WHERE amount > 150000;

-- Сравниваем время выполнения (Execution Time)
-- последовательное сканирование в нашем случае может быть дольше из-за случайных чтений.

SET enable_seqscan = DEFAULT;  -- Возвращаем



--  6. Выполните задания 3-4, 6-7, 14 со стр. 317-325 учебника Моргунов

-- 6.3 – CTE (общее табличное выражение), explain
EXPLAIN
WITH ticket_sort AS (
    SELECT ticket_no, passenger_id, passenger_name 
    FROM tickets 
    WHERE ticket_no LIKE '%2'
)
SELECT * FROM ticket_sort
ORDER BY passenger_id DESC 
LIMIT 10

-- CTE материализоваться и увидеть узел CTE Scan
EXPLAIN
WITH ticket_sort AS MATERIALIZED (
    SELECT ticket_no, passenger_id, passenger_name 
    FROM tickets 
    WHERE ticket_no LIKE '%2'
)
SELECT * FROM ticket_sort ORDER BY passenger_id DESC LIMIT 10;

-- Узел CTE Scan находится на уровне выше материализованного подзапроса. CTE‑блок вычисляется один раз (один Seq Scan), 
-- а затем используется для сортировки и лимита


-- 6.4 – Создание индекса для ускорения ORDER BY ... LIMIT (пример)

DROP TABLE IF EXISTS demo_order;
CREATE TABLE demo_order AS SELECT generate_series(1, 100000) AS id, random() AS val;

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)  -- Без индекса
SELECT id, val FROM demo_order ORDER BY val DESC LIMIT 10;

CREATE INDEX idx_demo_val ON demo_order (val);  -- Создаём индекс

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT id, val FROM demo_order ORDER BY val DESC LIMIT 10;
-- теперь Index Scan Backward


-- 6.6 – оконная функция
EXPLAIN
SELECT b.book_ref, b.total_amount, f.flight_no, avg(b.total_amount) OVER (PARTITION BY f.flight_no)
FROM bookings b
JOIN tickets t ON b.book_ref = t.book_ref
JOIN ticket_flights tf ON t.ticket_no = tf.ticket_no
JOIN flights f ON tf.flight_id = f.flight_id;
-- План содержит узел WindowAgg на верхнем уровне, т.к. оконная функция вычисляется после всех соединений


-- 6.7 Транзакции и блокировки (пример с DELETE и ROLLBACK)
CREATE TABLE example (col1 serial, col2 char(5));
INSERT INTO example VALUES (1, 'a'), (2, 'b');

BEGIN;
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
DELETE FROM example WHERE col1 = 1;
ROLLBACK; -- откатываем, чтобы не потерять данные
COMMIT; -- если нужно зафиксировать


-- 6.14 Сортировка с NULLS FIRST/LAST и влияние индекса
DROP TABLE IF EXISTS nulls;
CREATE TABLE nulls AS
SELECT num::integer, 'TEXT' || num::text AS txt
FROM generate_series(1, 200000) AS gen_ser(num);

CREATE INDEX nulls_ind ON nulls (num);
INSERT INTO nulls VALUES (NULL, 'TEXT');


-- 6.14.1 – Сортировка без подходящего индекса (Seq Scan + Sort)
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT * FROM nulls ORDER BY num DESC NULLS FIRST;


-- 6.14.2 – Создаём индекс с NULLS FIRST
CREATE INDEX nulls_first_idx ON nulls (num ASC NULLS FIRST);

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT * FROM nulls ORDER BY num NULLS FIRST;
-- теперь Index Scan


-- 6.14.3 Другие варианты сортировки и их планы
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT * FROM nulls ORDER BY num DESC NULLS LAST;

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT * FROM nulls ORDER BY num ASC NULLS LAST;

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT * FROM nulls ORDER BY num DESC NULLS FIRST;