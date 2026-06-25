-- 1. Таблица водителей
CREATE TABLE IF NOT EXISTS drivers (
    driver_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    license_number VARCHAR(20) UNIQUE NOT NULL,
    phone VARCHAR(15) UNIQUE,
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(10) NOT NULL DEFAULT 'active' 
        CHECK (status IN ('active', 'inactive', 'suspended'))
);

-- 2. Таблица автомобилей
CREATE TABLE IF NOT EXISTS cars (
    car_id SERIAL PRIMARY KEY,
    make VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    plate_number VARCHAR(10) UNIQUE NOT NULL,
    year INT CHECK (year >= 2000),
    driver_id INT UNIQUE,  -- один водитель – одна машина
    FOREIGN KEY (driver_id) 
        REFERENCES drivers(driver_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

-- 3. Таблица клиентов
CREATE TABLE IF NOT EXISTS clients (
    client_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE,
    rating NUMERIC(3,2) DEFAULT 5.00 CHECK (rating BETWEEN 0 AND 5)
);


-- Создание уникального индекса типа GiST, который проверяет не только равенство (=),
-- но и другие операторы, например && — пересечение, <@ — входит в диапазон, и т.д.
-- также по умолчанию EXCLUDE USING gist не умеет работать с обычными типами данных
-- такими как integer, text или timestamp, но работает с range, box, circle, geometry и т.д.
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 4. Таблица поездок
CREATE TABLE IF NOT EXISTS rides (
    ride_id SERIAL PRIMARY KEY,
    client_id INT NOT NULL,
    driver_id INT NOT NULL,
    car_id INT NOT NULL,
    start_location VARCHAR(100) NOT NULL,
    end_location VARCHAR(100) NOT NULL,
    distance_km NUMERIC(5,2) CHECK (distance_km > 0),
    ride_time INTERVAL NOT NULL,
    ride_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fare NUMERIC(10,2) NOT NULL CHECK (fare >= 0),

	-- Автоматически вычисляемый диапазон времени поездки
	ride_period TSRANGE GENERATED ALWAYS AS (
        tsrange(ride_date, ride_date + ride_time)
    ) STORED,

    -- Запрет перекрывающихся поездок для одного водителя
    EXCLUDE USING gist (
        driver_id WITH =,
        ride_period WITH &&
    ),

    CONSTRAINT fk_ride_client FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_ride_driver FOREIGN KEY (driver_id)
        REFERENCES drivers(driver_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_ride_car FOREIGN KEY (car_id)
        REFERENCES cars(car_id)
        ON DELETE NO ACTION
        ON UPDATE CASCADE
);

-- 5. Таблица оплат
CREATE TABLE IF NOT EXISTS payments (
    payment_id SERIAL PRIMARY KEY,
    ride_id INT NOT NULL,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    amount NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
    method VARCHAR(20) NOT NULL CHECK (method IN ('cash','card','bonus')),
    status VARCHAR(15) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','completed','failed')),

    CONSTRAINT fk_payment_ride FOREIGN KEY (ride_id)
        REFERENCES rides(ride_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

INSERT INTO drivers (full_name, license_number, phone, hire_date, status) VALUES
('Иван Петров', 'AB123456', '+79991234567', '2021-03-12', 'active'),
('Сергей Кузнецов', 'BC654321', '+79997654321', '2020-06-01', 'active'),
('Павел Смирнов', 'CD111222', '+79994567890', '2019-11-20', 'inactive'),
('Андрей Орлов', 'EF333444', '+79993456789', '2022-02-10', 'active'),
('Дмитрий Соколов', 'GH555666', '+79992345678', '2023-07-18', 'suspended');

INSERT INTO cars (make, model, plate_number, year, driver_id) VALUES
('Toyota', 'Camry', 'A123BC77', 2020, 1),
('Hyundai', 'Solaris', 'B456CD77', 2019, 2),
('Kia', 'Rio', 'C789DE77', 2021, 4),
('Skoda', 'Octavia', 'D111EE77', 2018, NULL),  -- без водителя
('Volkswagen', 'Polo', 'E222FF77', 2022, 5);

INSERT INTO clients (full_name, phone, email, rating) VALUES
('Анна Иванова', '+79998887766', 'anna@example.com', 4.8),
('Мария Петрова', '+79997776655', 'maria@example.com', 5.0),
('Олег Ким', '+79996665544', 'oleg@example.com', 4.5),
('Елена Смирнова', '+79995554433', 'elena@example.com', 4.9),
('Роман Волков', '+79994443322', 'roman@example.com', 4.7);

INSERT INTO rides (
    client_id, driver_id, car_id, start_location, end_location,
    distance_km, ride_time, ride_date, fare
)
VALUES
-- водитель 1, первая поездка
(1, 1, 1, 'Проспект Мира, 10', 'Тверская, 15',
 7.2, INTERVAL '18 minutes', '2025-10-21 10:00', 450.00),

-- водитель 1, вторая поездка — начинается после первой, не пересекается
(4, 1, 1, 'Арбат, 3', 'Кутузовский проспект, 20',
 8.5, INTERVAL '22 minutes', '2025-10-21 11:00', 520.00),

-- водитель 2
(2, 2, 2, 'Невский проспект, 25', 'Московский вокзал',
 3.5, INTERVAL '10 minutes', '2025-10-21 09:00', 250.00),

-- водитель 4
(3, 4, 3, 'Ленина, 5', 'Советская, 50',
 12.0, INTERVAL '25 minutes', '2025-10-21 12:00', 600.00),

-- водитель 5
(5, 5, 5, 'Пушкина, 8', 'Колхозная, 40',
 5.3, INTERVAL '15 minutes', '2025-10-21 13:00', 350.00);

-- Пример пересечения
-- Эта поездка начинается в 10:10 и пересекается с первой поездкой водителя №1 (10:00–10:18)
/*
INSERT INTO rides (client_id, driver_id, car_id, start_location, end_location,
                   distance_km, ride_time, ride_date, fare)
VALUES (6, 1, 1, 'Садовая, 20', 'Ленинский проспект, 5',
        6.0, INTERVAL '15 minutes', '2025-10-21 10:10', 400.00);
*/

INSERT INTO payments (ride_id, payment_date, amount, method, status) VALUES
(1, '2024-03-12 10:25', 450.00, 'card', 'completed'),
(2, '2024-03-12 12:10', 250.00, 'cash', 'completed'),
(3, '2024-03-13 15:30', 600.00, 'card', 'completed'),
(4, '2024-03-14 09:40', 520.00, 'bonus', 'completed'),
(5, '2024-03-14 11:00', 350.00, 'card', 'pending');

-- Все поездки с именами водителей и клиентов
SELECT r.ride_id, c.full_name AS client, d.full_name AS driver, r.fare, p.status AS payment_status
FROM rides r
JOIN clients c ON r.client_id = c.client_id
JOIN drivers d ON r.driver_id = d.driver_id
LEFT JOIN payments p ON p.ride_id = r.ride_id;

/*
DROP TABLE payments;
DROP TABLE rides;
DROP TABLE cars;
DROP TABLE clients;
DROP TABLE drivers;
*/





