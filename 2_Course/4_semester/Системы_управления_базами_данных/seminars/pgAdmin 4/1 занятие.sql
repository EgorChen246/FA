--dROP TABLE customers;

Create table if not exists customers(id SERIAL PRIMARY KEY, Age INT, Email Character varying(30));

insert into customers values(3,22, 'baz@bar.com');
Select * from customers;