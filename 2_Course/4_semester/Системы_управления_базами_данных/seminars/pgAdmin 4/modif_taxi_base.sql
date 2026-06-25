-- ========================================================
-- а. добавление/удаление/модификация столбцов и ограничений в существующие таблицы
--    (модифицировать не менее 3 таблиц).
-- ========================================================

-- 1. Добавляем столбец license_category в таблицу drivers
-- (категория водительских прав, с ограничением CHECK)
ALTER TABLE drivers
ADD COLUMN license_category VARCHAR(5)
    CHECK (license_category IN ('A','B','C','D','E'))
    DEFAULT 'B';

-- 2. Модифицируем тип и значение по умолчанию в таблице clients
-- (увеличиваем точность рейтинга)
-- Было NUMERIC(3,2) стало DECIMAL(4,2), разницы в типах нет (синонимы),
-- до этого значение 10.00 хранить было нельзя, а теперь можно

ALTER TABLE clients
DROP CONSTRAINT clients_rating_check;

ALTER TABLE clients
ALTER COLUMN rating TYPE DECIMAL(4,2),
ALTER COLUMN rating SET DEFAULT 5.00;

ALTER TABLE clients
ADD CONSTRAINT clients_rating_check CHECK (rating BETWEEN 0 AND 10);


-- 3. Изменяем ограничение для проверки года выпуска в таблице cars
-- (разрешаем автомобили с 1990 года и новее)
ALTER TABLE cars
DROP CONSTRAINT IF EXISTS cars_year_check,
ADD CONSTRAINT cars_year_check CHECK (year >= 1990);

-- ========================================================
-- б. Создание дополнительной таблицы maintenance (обслуживание)
-- ========================================================

CREATE TABLE maintenance (
    maintenance_id SERIAL PRIMARY KEY,
    car_id INT NOT NULL,
    service_date DATE NOT NULL DEFAULT CURRENT_DATE,
    service_type VARCHAR(50) NOT NULL,
    cost NUMERIC(10,2) CHECK (cost >= 0)
);

-- ========================================================
-- в. Добавление столбца в дополнительную таблицу
-- ========================================================

ALTER TABLE maintenance
ADD COLUMN comments TEXT;

-- ========================================================
-- г. Создание ограничения внешнего ключа для связи новой таблицы
--    с существующими таблицами (maintenance → cars)
-- ========================================================

ALTER TABLE maintenance
ADD CONSTRAINT fk_maintenance_car
FOREIGN KEY (car_id)
REFERENCES cars(car_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- ========================================================
-- д. Модификация столбца в таблице drivers
-- ========================================================

-- Увеличиваем длину телефонного номера (например, для международных форматов)
ALTER TABLE drivers
ALTER COLUMN phone TYPE VARCHAR(20);

-- ========================================================
-- е. Удаление столбца из таблицы drivers
-- ========================================================

ALTER TABLE drivers
DROP COLUMN IF EXISTS status;

-- ========================================================
-- ж. Удаление таблицы maintenance (пример удаления)
-- ========================================================

DROP TABLE IF EXISTS maintenance;
