-- Практика
SELECT * FROM aircrafts_data;
SELECT * FROM airports_data;
SELECT * FROM boarding_passes;
SELECT * FROM bookings;
SELECT * FROM flights;
SELECT * FROM seats;
SELECT * FROM ticket_flights;
SELECT * FROM tickets;


-- Задача №1.
-- Запрос, который находит аэропорт с наибольшей задержкой за август

SELECT * FROM flights;
SELECT * FROM airports_data;

WITH august_delays AS (
    SELECT 
        f.departure_airport,
        EXTRACT(EPOCH FROM (f.actual_departure - f.scheduled_departure)) / 60 AS delay_minutes
    FROM flights f
    WHERE EXTRACT(MONTH FROM f.scheduled_departure) = 8
      AND f.actual_departure IS NOT NULL
),

avg_delays AS (
    SELECT 
        departure_airport,
        AVG(delay_minutes) AS avg_delay
    FROM august_delays
    GROUP BY departure_airport
)

SELECT 
    a.airport_code,
    a.airport_name->>'ru' AS airport_name,
    ad.avg_delay
FROM avg_delays ad
JOIN airports_data a ON ad.departure_airport = a.airport_code
ORDER BY ad.avg_delay DESC
LIMIT 1;


-- Задача №2
-- Оконная функция, находящая 3 самых загруженных дня по кол-ву рейсов

SELECT * FROM flights;

WITH daily_counts AS (
    SELECT 
        scheduled_departure::date AS flight_date,
        COUNT(*) AS flights_count
    FROM flights
    GROUP BY flight_date
),

ranked_days AS (
    SELECT 
        flight_date,
        flights_count,
        ROW_NUMBER() OVER (ORDER BY flights_count DESC) AS rn
    FROM daily_counts
)

SELECT flight_date, flights_count FROM ranked_days WHERE rn <= 3
ORDER BY flights_count DESC;


-- Задача №3
-- Функция, рейсы на которых пассажиры чаще используют эконом-класс

SELECT * FROM ticket_flights;

DROP FUNCTION IF EXISTS top_economy_flights(INT);

CREATE OR REPLACE FUNCTION top_economy_flights(limit_n INT DEFAULT 5)
RETURNS TABLE(flight_id INT, economy_share NUMERIC)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tf.flight_id,
        ROUND(100.0 * COUNT(*) FILTER (WHERE tf.fare_conditions = 'Economy') / COUNT(*), 2) AS share
    FROM ticket_flights tf
    GROUP BY tf.flight_id
    HAVING COUNT(*) > 0
    ORDER BY share DESC
    LIMIT limit_n;
END;
$$;

SELECT * FROM top_economy_flights(3);


-- Задача №4
-- триггер и триггерную функцию для создания записи о пассажире в таблице контактов
-- при добавлении нового билета

SELECT * FROM tickets;

DROP TABLE IF EXISTS passenger_contacts CASCADE;

CREATE TABLE passenger_contacts (
    passenger_id VARCHAR(20) PRIMARY KEY,
    passenger_name TEXT,
    contact_data JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION sync_passenger_contact()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO passenger_contacts (passenger_id, passenger_name, contact_data)
    VALUES (NEW.passenger_id, NEW.passenger_name, NEW.contact_data)
    ON CONFLICT (passenger_id) DO UPDATE
    SET passenger_name = EXCLUDED.passenger_name,
        contact_data = EXCLUDED.contact_data;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tickets_sync_contact ON tickets;

CREATE TRIGGER trg_tickets_sync_contact
AFTER INSERT ON tickets
FOR EACH ROW
EXECUTE FUNCTION sync_passenger_contact();

INSERT INTO bookings (book_ref, book_date, total_amount)
VALUES ('ABC123', now(), 0)
ON CONFLICT (book_ref) DO NOTHING;

INSERT INTO tickets (ticket_no, book_ref, passenger_id, passenger_name, contact_data)
VALUES ('9999999999999', 'ABC123', '1234 567890', 'IVAN PETROV', '{"phone": "+71234567890"}');

SELECT * FROM passenger_contacts WHERE passenger_id = '1234 567890';

INSERT INTO tickets (ticket_no, book_ref, passenger_id, passenger_name, contact_data)
VALUES ('9999999999998', 'ABC123', '1234 567890', 'IVAN PETROV', '{"phone": "+79876543210", "email": "ivan@example.com"}');

SELECT * FROM passenger_contacts WHERE passenger_id = '1234 567890';


