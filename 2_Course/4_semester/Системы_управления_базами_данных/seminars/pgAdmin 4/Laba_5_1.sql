-- DROP TABLE deposits CASCADE;
-- DROP TABLE clients CASCADE;
-- DROP TABLE banks CASCADE;
-- DROP TABLE deposit_types CASCADE;
-- DROP TABLE IF EXISTS VIP_clients CASCADE;

CREATE TABLE banks(
	Id SERIAL,
	Num_of_branches INTEGER NOT NULL,
	Bank_name CHARACTER VARYING(30) UNIQUE,
	License_number INTEGER NOT NULL,
	Num_of_clients INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY (Id)
);

CREATE TABLE deposit_types(
	Id SERIAL,
	Type_name CHARACTER VARYING(30) NOT NULL,
	Interest_rate DECIMAL(5,2) NOT NULL,
	Min_amount DECIMAL(15,2),
	Max_amount DECIMAL(15,2),
	Duration_months INTEGER CHECK(Duration_months >= 1),
	PRIMARY KEY (Id)
);

CREATE TABLE deposits(
	Id SERIAL,
	Deposit_number CHARACTER VARYING(20) UNIQUE NOT NULL,
	Client_id INTEGER,
	Type_id INTEGER,
	Bank_name CHARACTER VARYING(30),
	Opening_date DATE DEFAULT CURRENT_DATE,
	Amount DECIMAL(15,2) CHECK(Amount > 0),
	PRIMARY KEY (Id),
	FOREIGN KEY (Bank_name) REFERENCES banks(Bank_name)
);

CREATE TABLE clients(
	Id SERIAL,
	Client_id INTEGER, -- UNIQUE,
	Client_name CHARACTER VARYING(30),
	Income_level INTEGER DEFAULT 30000,
	Age INTEGER CHECK(Age >= 18 AND Age <= 100),
	Bank_name CHARACTER VARYING(30),
	PRIMARY KEY (Id) --,
	-- FOREIGN KEY (Client_id) REFERENCES deposits(Client_id)
);

CREATE TABLE branches(
	Id SERIAL,
	Num_of_employees INTEGER CHECK(Num_of_employees >= 0),
	Bank_name CHARACTER VARYING(30),
	Address CHARACTER VARYING(100),
	Working_hours CHARACTER VARYING(50),
	PRIMARY KEY (Id),
	FOREIGN KEY (Bank_name) REFERENCES banks(Bank_name)
);

CREATE TABLE transactions(
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