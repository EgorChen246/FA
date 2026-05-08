-- Задание для 15 семинар

SELECT * FROM aircrafts_data;
SELECT * FROM airports_data;
SELECT * FROM boarding_passes;
SELECT * FROM bookings;
SELECT * FROM flights;
SELECT * FROM seats;
SELECT * FROM ticket_flights;
SELECT * FROM tickets;

-- Блок 1
-- Задание 1.1. Копирование нового самолёта в лог
SELECT * FROM aircrafts_data;

DROP TABLE IF EXISTS aircrafts_tmp, aircraft_log CASCADE;

CREATE TABLE aircrafts_tmp AS SELECT * FROM aircrafts_data;
CREATE TABLE aircraft_log (
    aircraft_code CHAR(3),
    model JSONB,
    range INTEGER,
    when_add TIMESTAMP,
    operation TEXT
);

CREATE OR REPLACE FUNCTION log_aircraft_insert()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO aircraft_log (aircraft_code, model, range, when_add, operation)
    VALUES (NEW.aircraft_code, NEW.model, NEW.range, CURRENT_TIMESTAMP, 'INSERT');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер (AFTER INSERT)
CREATE TRIGGER aircrafts_log_trigger
AFTER INSERT ON aircrafts_tmp  -- вставка
FOR EACH ROW
EXECUTE FUNCTION log_aircraft_insert();

INSERT INTO aircrafts_tmp (aircraft_code, model, range)
VALUES ('TST', '{"en":"Test plane"}', 5000);

SELECT * FROM aircraft_log;


-- Задание 1.2. Каскадное удаление связанных данных (рейсы и места)
SELECT * FROM aircrafts_data;
SELECT * FROM flights;
SELECT * FROM seats;

DROP TABLE IF EXISTS aircrafts_copy, flights_copy, seats_copy CASCADE;
CREATE TABLE aircrafts_copy AS SELECT * FROM aircrafts_data;
CREATE TABLE flights_copy AS SELECT * FROM flights;
CREATE TABLE seats_copy AS SELECT * FROM seats;

-- Триггерная функция (BEFORE DELETE)
CREATE OR REPLACE FUNCTION cascade_delete_aircraft()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM flights_copy WHERE aircraft_code = OLD.aircraft_code;  -- Удаляем рейсы, связанные с этим самолётом
    DELETE FROM seats_copy WHERE aircraft_code = OLD.aircraft_code;  -- Удаляем места
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Триггер
CREATE TRIGGER aircrafts_cascade_delete
BEFORE DELETE ON aircrafts_copy  -- перед удалением
FOR EACH ROW
EXECUTE FUNCTION cascade_delete_aircraft();

INSERT INTO aircrafts_copy SELECT * FROM aircrafts_data WHERE aircraft_code = '773';
INSERT INTO flights_copy (flight_id, flight_no, aircraft_code, status) 
VALUES (99999, 'TEST', '773', 'Scheduled');
INSERT INTO seats_copy SELECT * FROM seats WHERE aircraft_code = '773';
DELETE FROM aircrafts_copy WHERE aircraft_code = '773';
SELECT * FROM flights_copy WHERE aircraft_code = '773'; -- пусто
SELECT * FROM seats_copy WHERE aircraft_code = '773';   -- пусто


-- Задание 1.3. Автоматическое обновление суммы бронирования
-- Создаём функцию, обновляющую total_amount в bookings для заданного book_ref
SELECT * FROM ticket_flights;
SELECT * FROM tickets;

CREATE OR REPLACE FUNCTION update_booking_total(target_book_ref CHAR(6))
RETURNS VOID AS $$
BEGIN
    UPDATE bookings b
    SET total_amount = (
        SELECT COALESCE(SUM(tf.amount), 0)
        FROM tickets t
        JOIN ticket_flights tf ON t.ticket_no = tf.ticket_no
        WHERE t.book_ref = target_book_ref
    )
    WHERE b.book_ref = target_book_ref;
END;
$$ LANGUAGE plpgsql;

-- Триггерная функция для INSERT / UPDATE / DELETE на ticket_flights
CREATE OR REPLACE function sync_booking_total()
RETURNS TRIGGER AS $$
DECLARE
    affected_book_ref CHAR(6);
BEGIN
    IF (TG_OP = 'INSERT') THEN
        SELECT book_ref INTO affected_book_ref FROM tickets WHERE ticket_no = NEW.ticket_no;
        PERFORM update_booking_total(affected_book_ref);
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        SELECT book_ref INTO affected_book_ref FROM tickets WHERE ticket_no = OLD.ticket_no;
        PERFORM update_booking_total(affected_book_ref);
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        SELECT book_ref INTO affected_book_ref FROM tickets WHERE ticket_no = NEW.ticket_no;
        PERFORM update_booking_total(affected_book_ref);
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- триггеры
DROP TRIGGER IF EXISTS sync_booking_total_insert ON ticket_flights;
CREATE TRIGGER sync_booking_total_insert
AFTER INSERT ON ticket_flights
FOR EACH ROW EXECUTE FUNCTION sync_booking_total();

DROP TRIGGER IF EXISTS sync_booking_total_delete ON ticket_flights;
CREATE TRIGGER sync_booking_total_delete
AFTER DELETE ON ticket_flights
FOR EACH ROW EXECUTE FUNCTION sync_booking_total();

DROP TRIGGER IF EXISTS sync_booking_total_update ON ticket_flights;
CREATE TRIGGER sync_booking_total_update
AFTER UPDATE OF amount ON ticket_flights
FOR EACH ROW EXECUTE FUNCTION sync_booking_total();


BEGIN;

-- сумма бронирования 851B1C
SELECT book_ref, total_amount FROM bookings WHERE book_ref = '851B1C';

UPDATE ticket_flights
SET amount = amount + 1000
WHERE ticket_no = '000543847299';

SELECT book_ref, total_amount FROM bookings WHERE book_ref = '851B1C';

UPDATE ticket_flights
SET amount = amount - 1000
WHERE ticket_no = '000543847299';

SELECT book_ref, total_amount FROM bookings WHERE book_ref = '851B1C';

ROLLBACK;








