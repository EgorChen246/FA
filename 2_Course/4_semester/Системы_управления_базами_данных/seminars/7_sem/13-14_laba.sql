-- Задание для 13-14 семинар
-- Вариант 2

SELECT * FROM aircrafts_data;
SELECT * FROM airports_data;
SELECT * FROM boarding_passes;
SELECT * FROM bookings;
SELECT * FROM flights;
SELECT * FROM seats;
SELECT * FROM ticket_flights;
SELECT * FROM tickets;

-- Блок 1
-- Задание 1. Напишите SQL-функцию, которая по номеру билета выдаёт строку вида: Vladimir Frolov, contact_data: phone: ...
SELECT * FROM tickets;

CREATE OR REPLACE FUNCTION get_passenger_info(ticket_no_param TEXT)
RETURNS TEXT AS $$
DECLARE
    passenger_details TEXT;
    passenger_name_text TEXT;
    phone_text TEXT;
BEGIN
    SELECT 
        passenger_name,
        contact_data->>'phone'
    INTO 
        passenger_name_text,
        phone_text
    FROM tickets WHERE ticket_no = ticket_no_param;
    
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    
    -- первая буква каждого слова заглавная, остальные строчные
    passenger_name_text := INITCAP(passenger_name_text);
    
    -- Если телефон не указан, пишем 'не указан'
    IF phone_text IS NULL THEN
        phone_text := 'не указан';
    END IF;
   
    passenger_details := passenger_name_text || ' contact_data: phone: ' || phone_text;
    
    RETURN passenger_details;
END;
$$ LANGUAGE plpgsql;

SELECT get_passenger_info('0005433848165');

-- Задание 2. Функция с VARIADIC, возвращающая таблицу
SELECT * FROM ticket_flights;
SELECT * FROM tickets;

CREATE OR REPLACE FUNCTION get_ticket_details(VARIADIC ticket_nos TEXT[])
RETURNS TABLE(passenger_id VARCHAR(20), passenger_name TEXT, amount NUMERIC, fare_conditions VARCHAR(10)) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.passenger_id,
        t.passenger_name,
        tf.amount,
        tf.fare_conditions
    FROM tickets t
    JOIN ticket_flights tf ON t.ticket_no = tf.ticket_no
    WHERE t.ticket_no = ANY(ticket_nos);
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_ticket_details('0005433848165', '0005433848166', '0005433848167');

-- Задание 3. Функция, возвращающая количество пассажиров эконом-класса на рейсе
SELECT * FROM ticket_flights;
SELECT * FROM tickets;

DROP FUNCTION IF EXISTS get_economy_passenger_count(INT);

CREATE OR REPLACE FUNCTION get_economy_passenger_count(flight_id_param INT)
RETURNS INT AS $$
DECLARE
    economy_passenger_count INT;
BEGIN
    SELECT COUNT(*)
    INTO economy_passenger_count
    FROM ticket_flights WHERE flight_id = flight_id_param AND fare_conditions = 'Economy';
    
    RETURN COALESCE(economy_passenger_count, 0);
END;
$$ LANGUAGE plpgsql;

SELECT get_economy_passenger_count(306);


-- Блок 2
-- Задание 1. Функция с составным типом booking_type
DROP TYPE IF EXISTS booking_type CASCADE;
CREATE TYPE booking_type AS (
    book_ref CHAR(6),
    book_date TIMESTAMPTZ,
    total_amount NUMERIC
);

CREATE OR REPLACE FUNCTION reduce_total_amount(booking_record booking_type)
RETURNS NUMERIC AS $$
BEGIN
    RETURN booking_record.total_amount * 0.7;
END;
$$ LANGUAGE plpgsql;


SELECT reduce_total_amount(ROW('ABC123', now(), 1000.00)::booking_type);


-- Задание 2. Процедура update_contact_data
CREATE OR REPLACE PROCEDURE update_contact_data(passenger_ids VARCHAR(20)[], phone_numbers TEXT[])
LANGUAGE plpgsql AS $$
DECLARE
    i INT;
BEGIN
    IF array_length(passenger_ids, 1) IS DISTINCT FROM array_length(phone_numbers, 1) THEN
        RAISE EXCEPTION 'Массивы должны быть одинаковой длины';
    END IF;

    FOR i IN 1 .. array_length(passenger_ids, 1) LOOP
        UPDATE tickets
        SET contact_data = COALESCE(contact_data, '{}'::jsonb) || jsonb_build_object('phone', phone_numbers[i])
        WHERE passenger_id = passenger_ids[i];
    END LOOP;
END;
$$;

SELECT passenger_id, contact_data FROM tickets WHERE passenger_id IN ('4778 373635', '2293 606923');


-- Задание 3. Функция calculate_difference (VARIADIC)
CREATE OR REPLACE FUNCTION calculate_difference(VARIADIC numbers NUMERIC[])
RETURNS NUMERIC AS $$
DECLARE
    result NUMERIC;
    i INT;
BEGIN
    IF array_length(numbers, 1) IS NULL OR array_length(numbers, 1) = 0 THEN
        RETURN NULL;
    END IF;
    
    result := numbers[1];
    FOR i IN 2 .. array_length(numbers, 1) LOOP
        result := result - numbers[i];
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

SELECT calculate_difference(100, 10, 5, 2);


-- Задание 4. Функция generate_ticket_flights_table
SELECT * FROM flights;
SELECT * FROM ticket_flights;
SELECT * FROM tickets;

CREATE OR REPLACE FUNCTION generate_ticket_flights_table(fare_cond VARCHAR(10))
RETURNS TABLE(ticket_no CHAR(13), flight_id INT, fare_conditions VARCHAR(10), amount NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT tf.ticket_no, tf.flight_id, tf.fare_conditions, tf.amount
    FROM ticket_flights tf
    WHERE tf.fare_conditions = fare_cond;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM generate_ticket_flights_table('Economy') LIMIT 10;


-- Задание 5. Два варианта функций (SETOF и SETOF RECORD)
-- Вариант 1 (SETOF ticket_flights)
CREATE OR REPLACE FUNCTION get_ticket_flights_by_fare_cond(fare_cond VARCHAR(10))
RETURNS SETOF ticket_flights AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM ticket_flights
    WHERE fare_conditions = fare_cond;
END;
$$ LANGUAGE plpgsql;

-- Вариант 2 (SETOF RECORD)
CREATE OR REPLACE FUNCTION get_ticket_flights_by_fare_cond_record(fare_cond VARCHAR(10))
RETURNS SETOF RECORD AS $$
BEGIN
    RETURN QUERY
    SELECT tf.ticket_no, tf.flight_id, tf.fare_conditions, tf.amount
    FROM ticket_flights tf
    WHERE tf.fare_conditions = fare_cond;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_ticket_flights_by_fare_cond_record('Economy') 
AS (ticket_no CHAR(13), flight_id INT, fare_conditions VARCHAR, amount NUMERIC)
LIMIT 10;


-- Блок 3
-- 1. Переменная на четырёх уровнях вложенности

CREATE OR REPLACE FUNCTION nested_variable_demo()
RETURNS VOID AS $$
DECLARE
    msg TEXT := 'Уровень 1 (внешний)';
BEGIN
    RAISE NOTICE '%', msg;
    BEGIN
        msg := 'Уровень 2 (первый вложенный)';
        RAISE NOTICE '%', msg;
        BEGIN
            msg := 'Уровень 3 (второй вложенный)';
            RAISE NOTICE '%', msg;
            BEGIN
                msg := 'Уровень 4 (третий вложенный)';
                RAISE NOTICE '%', msg;
            END;
        END;
    END;
END;
$$ LANGUAGE plpgsql;

SELECT nested_variable_demo();


-- 2. Динамические команды (SELECT, UPDATE, DELETE)
SELECT * FROM flights;
SELECT * FROM ticket_flights;
SELECT * FROM tickets;

DROP TABLE IF EXISTS flights_copy, ticket_flights_copy;
CREATE TABLE flights_copy AS SELECT * FROM flights;
CREATE TABLE ticket_flights_copy AS SELECT * FROM ticket_flights;

SELECT COUNT(*) FROM flights_copy;
SELECT COUNT(*) FROM ticket_flights_copy;


DROP FUNCTION IF EXISTS dynamic_commands_demo(TEXT, INT, TEXT, VARCHAR);

CREATE OR REPLACE FUNCTION dynamic_commands_demo(
    table_name TEXT,
    flight_id_param INT,
    new_status TEXT,
    fare_cond_param VARCHAR
)
RETURNS VOID AS $$
DECLARE
    rec RECORD;
    update_query TEXT;
    delete_query TEXT;
    updated_rows INT;
    deleted_rows INT;
BEGIN
    -- Динамический SELECT
    EXECUTE format('SELECT * FROM %I LIMIT 5', table_name) INTO rec;
    RAISE NOTICE 'Первая строка из %: %', table_name, rec;

    -- Динамический UPDATE
    update_query := 'UPDATE flights_copy SET status = $1 WHERE flight_id = $2';
    EXECUTE update_query USING new_status, flight_id_param;
    GET DIAGNOSTICS updated_rows = ROW_COUNT;  -- получаем количество обновлённых строк
    RAISE NOTICE 'Обновлено строк в flights_copy: %', updated_rows;

    -- Динамический DELETE
    delete_query := 'DELETE FROM ticket_flights_copy WHERE fare_conditions = $1';
    EXECUTE delete_query USING fare_cond_param;
    GET DIAGNOSTICS deleted_rows = ROW_COUNT;  -- получаем количество удалённых строк
    RAISE NOTICE 'Удалено строк из ticket_flights_copy: %', deleted_rows;
END;
$$ LANGUAGE plpgsql;


SELECT dynamic_commands_demo('flights_copy', 306, 'Cancelled', 'Economy');


-- 3. Переписывание SQL-функций из заданий 4–5

-- 4. Процедура сравнения мест в таблице seats
SELECT * FROM seats;

DROP PROCEDURE IF EXISTS find_seat_pairs_by_last_char();

CREATE OR REPLACE PROCEDURE find_seat_pairs_by_last_char()
LANGUAGE plpgsql AS $$
DECLARE
    r1 RECORD;
    r2 RECORD;
BEGIN
    FOR r1 IN SELECT seat_no FROM seats LOOP
        FOR r2 IN SELECT seat_no FROM seats WHERE seat_no > r1.seat_no LOOP
            IF RIGHT(r1.seat_no, 1) != RIGHT(r2.seat_no, 1) THEN
                RAISE NOTICE 'Пара: % и %', r1.seat_no, r2.seat_no;
            END IF;
        END LOOP;
    END LOOP;
END;
$$;

-- CALL find_seat_pairs_by_last_char();


-- 5. Курсор с параметром (flights + aircrafts)
SELECT * FROM aircrafts_data;
SELECT * FROM flights;

DROP FUNCTION IF EXISTS show_flights_by_aircraft_model(aircraft_model TEXT);

CREATE OR REPLACE FUNCTION show_flights_by_aircraft_model(aircraft_model TEXT)
RETURNS VOID AS $$
DECLARE
    cur CURSOR (model_param TEXT) FOR
        SELECT f.flight_id, f.flight_no, f.departure_airport, f.arrival_airport,
               ad.model->>'en' AS model
        FROM flights f
        JOIN aircrafts_data ad ON f.aircraft_code = ad.aircraft_code
        WHERE ad.model->>'en' = model_param;
    rec RECORD;
BEGIN
    OPEN cur(aircraft_model);
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Рейс %: % -> %, модель %', rec.flight_id, rec.departure_airport, rec.arrival_airport, rec.model;
    END LOOP;
    CLOSE cur;
END;
$$ LANGUAGE plpgsql;


SELECT show_flights_by_aircraft_model('Boeing 777-300');




