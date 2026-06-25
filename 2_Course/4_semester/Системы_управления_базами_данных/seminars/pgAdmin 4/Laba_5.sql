-- Table: public.Egory_table (lab 5)
-- DROP TABLE IF EXISTS public."Egory_table (lab 5)";

DROP TABLE IF EXISTS deposits CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS banks CASCADE;
DROP TABLE IF EXISTS deposit_types CASCADE;
DROP TABLE IF EXISTS VIP_clients CASCADE;

CREATE TABLE IF NOT EXISTS banks(
	Id SERIAL,
	Num_of_branches INTEGER NOT NULL,
	Bank_name CHARACTER VARYING(30) UNIQUE,
	License_number INTEGER NOT NULL UNIQUE,
	Num_of_clients INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY (Id)
);

CREATE TABLE IF NOT EXISTS deposit_types(
	Id SERIAL,
	Type_name CHARACTER VARYING(30) NOT NULL UNIQUE,
	Interest_rate DECIMAL(5,2) NOT NULL,
	Min_amount DECIMAL(15,2),
	Max_amount DECIMAL(15,2),
	Duration_months INTEGER CHECK(Duration_months >= 1),
	PRIMARY KEY (Id)
);

CREATE TABLE IF NOT EXISTS deposits(
	Id SERIAL,
	Deposit_number CHARACTER VARYING(20) UNIQUE NOT NULL,
	Client_id INTEGER UNIQUE,
	Type_id INTEGER,
	Bank_name CHARACTER VARYING(30),
	Opening_date DATE DEFAULT CURRENT_DATE,
	Amount DECIMAL(15,2) CHECK(Amount > 0),
	PRIMARY KEY (Id),
	FOREIGN KEY (Bank_name) REFERENCES banks(Bank_name),
	FOREIGN KEY (Type_id) REFERENCES deposit_types(Id)
);

CREATE TABLE IF NOT EXISTS clients(
	Id SERIAL,
	Client_id INTEGER UNIQUE,
	Client_name CHARACTER VARYING(30),
	Income_level INTEGER DEFAULT 30000,
	Age INTEGER CHECK(Age >= 18 AND Age <= 100),
	Bank_name CHARACTER VARYING(30),
	PRIMARY KEY (Id),
	FOREIGN KEY (Client_id) REFERENCES deposits(Client_id),
	FOREIGN KEY (Bank_name) REFERENCES banks(Bank_name)
);

CREATE TABLE IF NOT EXISTS branches(
	Id SERIAL,
	Num_of_employees INTEGER CHECK(Num_of_employees >= 0),
	Bank_name CHARACTER VARYING(30),
	Address CHARACTER VARYING(100),
	Working_hours CHARACTER VARYING(50),
	PRIMARY KEY (Id),
	FOREIGN KEY (Bank_name) REFERENCES banks(Bank_name)
);

CREATE TABLE IF NOT EXISTS transactions(
	Id SERIAL,
	Bank_name CHARACTER VARYING(30),
	Client_name CHARACTER VARYING(30) NOT NULL UNIQUE,
	Transaction_date DATE NOT NULL,
	Amount DECIMAL(15,2) CHECK(Amount >= 0) DEFAULT 0,
	Transaction_type CHARACTER VARYING(20) CHECK(Transaction_type IN ('deposit', 'withdrawal', 'transfer')),
	PRIMARY KEY (Id),
	CONSTRAINT Bank_name_fk FOREIGN KEY (Bank_name)
		REFERENCES banks(Bank_name)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
);

-- a. добавление/удаление/модификация столбцов и ограничений
ALTER TABLE banks
ADD City CHARACTER VARYING(30);

ALTER TABLE clients
ADD Client_phone CHARACTER VARYING(20) NOT NULL;

ALTER TABLE deposits
DROP COLUMN Opening_date;

-- б. создание дополнительной таблицы
CREATE TABLE IF NOT EXISTS VIP_clients(
	Id SERIAL,
	Client_name CHARACTER VARYING(30) NOT NULL,
	PRIMARY KEY (Id)
);

-- в. добавление столбца в дополнительную таблицу
ALTER TABLE VIP_clients
ADD Total_deposits DECIMAL(15,2);

-- г. создание ограничения внешнего ключа для связи новой таблицы с существующими
ALTER TABLE VIP_clients
ADD CONSTRAINT Client_name_fk FOREIGN KEY (Client_name)
	REFERENCES transactions(Client_name) MATCH FULL;

-- д. модификация столбца в таблице
ALTER TABLE clients
ALTER COLUMN Income_level TYPE DECIMAL(10,2);

-- е. удаление столбца из таблицы
-- ALTER TABLE transactions
-- DROP COLUMN Transaction_type;

-- ж. удаления таблицы
-- DROP TABLE VIP_clients CASCADE;