-- Контрольная работа №2 (05.06.26)
-- Ченцов Егор, ИД24-3, Вариант 2

SELECT * FROM aircrafts_data;
SELECT * FROM airports_data;
SELECT * FROM boarding_passes;
SELECT * FROM bookings;
SELECT * FROM flights;
SELECT * FROM seats;
SELECT * FROM ticket_flights;
SELECT * FROM tickets;


/* 1. Напишите функцию, которая выводит среднюю выручку на кресло в зависимости от класса 
обслуживания. Входные параметры: fare_conditions, выходные параметры: revenue 
(numeric) */

SELECT * FROM ticket_flights
SELECT * FROM seats;

CREATE OR REPLACE FUNCTION avg_revenue_per_seat(fare_cond VARCHAR(10))
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
	total_revenue NUMERIC;
	total_seats   NUMERIC;
	avg_revenue   NUMERIC;
BEGIN
	SELECT COALESCE(SUM(amount), 0) INTO total_revenue FROM ticket_flights
	WHERE fare_conditions = fare_cond; -- общая выручка по данному классу

	
	SELECT COALESCE(COUNT(*), 0) INTO total_seats FROM seats
	WHERE fare_conditions = fare_cond;  -- кол-во кресел данного класса во всех самолётах

	IF total_seats = 0 THEN RETURN 0;
	END IF;

	avg_revenue := total_revenue / total_seats;
	RETURN avg_revenue;
END;
$$;

SELECT avg_revenue_per_seat('Economy');
SELECT avg_revenue_per_seat('Business');
SELECT avg_revenue_per_seat('Comfort');


/* 2. Реализуйте процедуру возврата денег по брони. На вход процедура получает код брони 
book_ref, а сама процедура должна удалить бронь и билеты из нее из всех связанных 
таблиц (bookings, tickets, ticket_flights). */

SELECT * FROM tickets;
SELECT * FROM ticket_flights;
SELECT * FROM bookings;

CREATE OR REPLACE PROCEDURE cancel_booking(p_book_ref CHAR(6))
LANGUAGE plpgsql
AS $$
DECLARE
	v_ticket_no CHAR(13);
BEGIN
    -- Удаляем записи из ticket_flights для всех билетов брони
    FOR v_ticket_no IN SELECT ticket_no FROM tickets WHERE book_ref = p_book_ref
    LOOP 
	DELETE FROM ticket_flights WHERE ticket_no = v_ticket_no;
    END LOOP;

    DELETE FROM tickets WHERE book_ref = p_book_ref;  -- Удаляем билеты брони
    DELETE FROM bookings WHERE book_ref = p_book_ref;  -- Удаляем саму бронь

    COMMIT;
END;
$$;

--

SELECT book_ref FROM bookings LIMIT 5;
CALL cancel_booking('000068');  -- пример номера


/* 3. Создайте копию таблицы flights – flights_log, в которую будут записываться отмененные 
рейсы. Создайте триггерную функцию и триггер, который будет собирать [новую] таблицу с 
выручкой по отмененным рейсам (в таблице flights есть поле «status»). Важно учесть, что 
во flights_log может появиться новая запись с рейсом со статусом cancelled, а также статус 
может быть изменен для действующего рейса. */

SELECT * FROM flights;
SELECT * FROM ticket_flights;
SELECT * FROM tickets;

-- Создайте копию таблицы flights – flights_log

DROP TABLE IF EXISTS flights_log;

CREATE TABLE flights_log (
    LIKE flights INCLUDING ALL,
    revenue NUMERIC,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создайте триггерную функцию

CREATE OR REPLACE FUNCTION log_cancelled_flight()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
	v_revenue NUMERIC;
BEGIN
	-- Проверяем, что новый статус = 'Cancelled' (изменение/вставка)
	IF (TG_OP = 'INSERT' AND NEW.status = 'Cancelled') OR (TG_OP = 'UPDATE' AND NEW.status = 'Cancelled' AND OLD.status != 'Cancelled')
	
	THEN
		SELECT COALESCE(SUM(amount), 0) INTO v_revenue FROM ticket_flights
		WHERE flight_id = NEW.flight_id;  -- Вычисляем выручку по этому рейсу

		-- Вставляем запись в лог
		INSERT INTO flights_log (flight_id, flight_no, scheduled_departure, scheduled_arrival,
								departure_airport, arrival_airport, status, aircraft_code,
								actual_departure, actual_arrival, revenue)
		VALUES (NEW.flight_id, NEW.flight_no, NEW.scheduled_departure, NEW.scheduled_arrival,
				NEW.departure_airport, NEW.arrival_airport, NEW.status, NEW.aircraft_code,
				NEW.actual_departure, NEW.actual_arrival, v_revenue);
	END IF;

	RETURN NEW;  -- Для BEFORE триггера возвращаем NEW, чтобы операция прошла
END;
$$;

-- Создайте триггерную функцию и ТРИГГЕР

DROP TRIGGER IF EXISTS flights_cancel_log_trigger ON flights;

CREATE TRIGGER flights_cancel_log_trigger
AFTER INSERT OR UPDATE OF status ON flights
FOR EACH ROW
EXECUTE FUNCTION log_cancelled_flight();

-- 

SELECT flight_id, status FROM flights LIMIT 5;  -- Исходные данные

UPDATE flights SET status = 'Cancelled' WHERE flight_id = 4;  -- Отменяем один из рейсов
SELECT * FROM flights_log;  -- Смотрим лог

DELETE FROM flights WHERE flight_id = 99999;

INSERT INTO flights (flight_id, flight_no, scheduled_departure, scheduled_arrival, departure_airport, arrival_airport, status, aircraft_code)
VALUES (99999, 'TEST01', now(), now()+interval '2 hours', 'DME', 'SVO', 'Cancelled', '319');












