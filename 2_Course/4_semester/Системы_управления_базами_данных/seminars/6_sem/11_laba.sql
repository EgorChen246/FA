-- Задание для 11 семинара


DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS cart_items CASCADE;
DROP TABLE IF EXISTS carts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS stock CASCADE;
DROP TABLE IF EXISTS warehouses CASCADE;
DROP TABLE IF EXISTS book_authors CASCADE;
DROP TABLE IF EXISTS books CASCADE;
DROP TABLE IF EXISTS authors CASCADE;
DROP TABLE IF EXISTS publishers CASCADE;


-- 1. Издатель
CREATE TABLE publishers (
    publisher_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    website VARCHAR(255)
);

-- 2. Автор
CREATE TABLE authors (
    author_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    address TEXT,
    website VARCHAR(255)
);

-- 3. Книга
CREATE TABLE books (
    isbn VARCHAR(13) PRIMARY KEY,  -- естественный ключ
    title VARCHAR(255) NOT NULL,
    publication_year INT CHECK (publication_year BETWEEN 1500 AND EXTRACT(YEAR FROM CURRENT_DATE)),
    price NUMERIC(10,2) NOT NULL,
    description TEXT,
    publisher_id INT NOT NULL,
    CONSTRAINT fk_books_publishers FOREIGN KEY (publisher_id) REFERENCES publishers(publisher_id)
);

-- 4. Связка Книга-Автор многие-ко-многим
CREATE TABLE book_authors (
    isbn VARCHAR(13) NOT NULL,
    author_id INT NOT NULL,
    PRIMARY KEY (isbn, author_id),
    CONSTRAINT fk_ba_books FOREIGN KEY (isbn) REFERENCES books(isbn) ON DELETE CASCADE,
    CONSTRAINT fk_ba_authors FOREIGN KEY (author_id) REFERENCES authors(author_id) ON DELETE CASCADE
);

-- 5. Склад
CREATE TABLE warehouses (
    warehouse_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    address VARCHAR(255) NOT NULL,
    phone VARCHAR(20)
);

-- 6. Остаток на складе (связка книга-склад)
CREATE TABLE stock (
    isbn VARCHAR(13) NOT NULL,
    warehouse_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    PRIMARY KEY (isbn, warehouse_id),
    CONSTRAINT fk_stock_books FOREIGN KEY (isbn) REFERENCES books(isbn),
    CONSTRAINT fk_stock_warehouses FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);

-- 7. Покупатель
CREATE TABLE customers (
    customer_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT
);

-- 8. Корзина
CREATE TABLE carts (
    cart_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'ordered', 'abandoned')),
    CONSTRAINT fk_carts_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);

-- 9. Элементы корзины (связка корзина-книга)
CREATE TABLE cart_items (
    cart_id INT NOT NULL,
    isbn VARCHAR(13) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (cart_id, isbn),
    CONSTRAINT fk_ci_carts FOREIGN KEY (cart_id) REFERENCES carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_ci_books FOREIGN KEY (isbn) REFERENCES books(isbn)
);

-- 10. Заказ
CREATE TABLE orders (
    order_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount NUMERIC(12,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled')),
    payment_address TEXT,
    shipping_address TEXT,
    shipping_method VARCHAR(50),
    payment_details TEXT,
    CONSTRAINT fk_orders_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- 11. Элементы заказа (связка заказ-книга)
CREATE TABLE order_items (
    order_id INT NOT NULL,
    isbn VARCHAR(13) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    price_at_order NUMERIC(10,2) NOT NULL, -- цена на момент заказа
    PRIMARY KEY (order_id, isbn),
    CONSTRAINT fk_oi_orders FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_oi_books FOREIGN KEY (isbn) REFERENCES books(isbn)
);

-- 12. Уведомление
CREATE TABLE notifications (
    notification_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INT NOT NULL,
    email VARCHAR(255) NOT NULL,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    message TEXT,
    CONSTRAINT fk_notifications_orders FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

/*
DROP TABLE IF EXISTS 
    notifications,
    order_items,
    orders,
    cart_items,
    carts,
    customers,
    stock,
    warehouses,
    book_authors,
    books,
    authors,
    publishers
CASCADE;

SELECT * FROM notifications;
SELECT * FROM order_items;
SELECT * FROM orders;
SELECT * FROM cart_items;
SELECT * FROM carts;
SELECT * FROM customers;
SELECT * FROM stock;
SELECT * FROM warehouses;
SELECT * FROM book_authors;
SELECT * FROM books;
SELECT * FROM authors;
SELECT * FROM publishers; */