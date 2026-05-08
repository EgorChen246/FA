-- Задание для 16 семинар
-- Вариант 18

DROP TABLE IF EXISTS Пациенты, Услуги, ОказанныеУслуги CASCADE;

CREATE TABLE Пациенты (
    Номер INT PRIMARY KEY,
    Фамилия TEXT,
    Адрес TEXT,
    Год_рождения INT
);

CREATE TABLE Услуги (
    Код INT PRIMARY KEY,
    Название TEXT
);

CREATE TABLE ОказанныеУслуги (
    Пациент INT REFERENCES Пациенты(Номер),
    Услуга INT REFERENCES Услуги(Код),
    Время TIME,
    Стоимость NUMERIC(10,2),
    PRIMARY KEY (Пациент, Услуга, Время)
);

INSERT INTO Пациенты VALUES
(1,'Петров','Солнечная, д. 46',1989),
(2,'Иванов','Рыбинская, д. 22',1961),
(3,'Попова','Горького, д. 17',1964),
(4,'Зотов','Полякова, д. 10',1984),
(5,'Ковалев','Свободы, д. 71',1989),
(6,'Саврюев','МЦП, д. 66',1990),
(7,'Тарасюка','Солнечная, д. 10',1973),
(8,'Ильин','Урицкого, д. 67',1987),
(9,'Сафронова','Каменная, д. 13',1980);

INSERT INTO Услуги VALUES
(100,'Удаление зубов'),
(101,'Лечение зубов'),
(102,'Протезирование'),
(103,'Отбеливание'),
(104,'Чистка полости рта'),
(105,'Декоративное украшение зубов'),
(106,'Рентгенодиагностика'),
(107,'Пародонтология'),
(108,'Исправление прикуса'),
(109,'Реставрация зубов');

INSERT INTO ОказанныеУслуги VALUES
(1,102,'12:00:00',600),
(2,104,'15:00:00',500),
(3,106,'08:45:00',200),
(4,104,'17:00:00',300),
(5,105,'21:00:00',750),
(6,103,'19:00:00',400),
(7,102,'12:00:00',500),
(8,106,'08:45:00',200),
(9,104,'15:00:00',500);

SELECT * FROM Пациенты;
SELECT * FROM Услуги;
SELECT * FROM ОказанныеУслуги;

-- 1.1. AFTER-триггер (фактически BEFORE DELETE), запрещающий удаление услуги с кодом 100
SELECT * FROM Услуги;

CREATE OR REPLACE FUNCTION prevent_delete_service_100()

RETURNS TRIGGER AS $$
BEGIN
    IF OLD.Код = 100 THEN
        RAISE EXCEPTION 'Нельзя удалить услугу с кодом 100!';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_services_before_delete
BEFORE DELETE ON Услуги  -- перед удалением
FOR EACH ROW
EXECUTE FUNCTION prevent_delete_service_100();

DELETE FROM Услуги WHERE Код = 100;  -- ошибка
DELETE FROM Услуги WHERE Код = 101;  -- удалится


-- 1.2. Триггер, разрешающий увеличение стоимости только в большую сторону
CREATE OR REPLACE FUNCTION check_cost_increase()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Стоимость <= OLD.Стоимость THEN
        RAISE EXCEPTION 'Стоимость можно только увеличить (текущее: %, новое: %)', OLD.Стоимость, NEW.Стоимость;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_services_cost_before_update
BEFORE UPDATE OF Стоимость ON ОказанныеУслуги  -- до новых значений
FOR EACH ROW
EXECUTE FUNCTION check_cost_increase();

UPDATE ОказанныеУслуги SET Стоимость = 700 WHERE Пациент=1 AND Услуга=102 AND Время='12:00:00'; -- работает
UPDATE ОказанныеУслуги SET Стоимость = 500 WHERE Пациент=1 AND Услуга=102 AND Время='12:00:00'; -- ошибка


-- 2.1. Представление с информацией об оказанных услугах
CREATE VIEW ОказанныеУслуги_View AS
SELECT 
    p.Номер AS Номер_пациента,
    p.Фамилия,
    u.Код AS Код_услуги,
    u.Название AS Название_услуги,
    o.Время,
    o.Стоимость
FROM ОказанныеУслуги o
JOIN Пациенты p ON o.Пациент = p.Номер
JOIN Услуги u ON o.Услуга = u.Код;

SELECT * FROM ОказанныеУслуги_View;


-- 2.2. Триггер INSTEAD OF INSERT для вставки через представление
CREATE OR REPLACE FUNCTION insert_into_services_view()
RETURNS TRIGGER AS $$
DECLARE
    patient_exists INT;
    service_exists INT;
BEGIN
    -- Проверяем существование пациента
    SELECT COUNT(*) INTO patient_exists FROM Пациенты WHERE Номер = NEW.Номер_пациента;
    IF patient_exists = 0 THEN
        RAISE EXCEPTION 'Пациент с номером % не существует', NEW.Номер_пациента;
    END IF;

    -- Проверяем существование услуги
    SELECT COUNT(*) INTO service_exists FROM Услуги WHERE Код = NEW.Код_услуги;
    IF service_exists = 0 THEN
        RAISE EXCEPTION 'Услуга с кодом % не существует', NEW.Код_услуги;
    END IF;

    INSERT INTO ОказанныеУслуги (Пациент, Услуга, Время, Стоимость)
    VALUES (NEW.Номер_пациента, NEW.Код_услуги, NEW.Время, NEW.Стоимость);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_services_view_insert
INSTEAD OF INSERT ON ОказанныеУслуги_View  -- вместо ставки
FOR EACH ROW
EXECUTE FUNCTION insert_into_services_view();

INSERT INTO ОказанныеУслуги_View (Номер_пациента, Фамилия, Код_услуги, Название_услуги, Время, Стоимость)
VALUES (10, 'Новый', 100, 'Удаление', '10:00:00', 1000);  -- ошибка: нет пациента
VALUES (1, 'Петров', 200, 'Несуществующая', '11:00:00', 500); -- ошибка: нет услуги
VALUES (1, 'Петров', 101, 'Лечение зубов', '11:00:00', 5000); -- успешно





