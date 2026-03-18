--  ====================================================================================================================
--  CTE NIEREKURENCYJNE
--  ====================================================================================================================

create table customers(
    customer_id int auto_increment primary key,
    name varchar(100)
);

create table products(
    product_id int primary key auto_increment,
    product_name varchar(100),
    price decimal(10,2)
);

create table orders(
    order_id int primary key auto_increment,
    customer_id int,
    order_date date,
    foreign key (customer_id) references customers(customer_id) on delete cascade on update cascade
);

create table order_items(
    order_item_id int primary key auto_increment,
    order_id int,
    product_id int,
    quantity int,
    foreign key (order_id) references orders(order_id) on delete cascade on update cascade,
    foreign key (product_id) references products(product_id) on delete cascade on update cascade
);

insert into customers (name)
values ('Anna'),
       ('Bartek');

insert into products (product_name, price)
values ('Laptop', 3000),
       ('Myszka', 100),
       ('Monitor', 800);

insert into products (product_name, price)
values ('Klawiatura', 200);

insert into orders (customer_id, order_date)
values (1, '2025-07-01'),
       (1, '2025-07-05'),
       (2, '2025-07-06');

insert into order_items (order_id, product_id, quantity)
values (1, 1, 1),
       (1, 2, 2),
       (2, 3, 1),
       (3, 2, 1);

-- Zadanie 1
-- Wyswietl liste zamowien z data i nazwa klienta.

with order_list as (
    select o.order_id, o.order_date, c.name as customer_name
    from orders o
    join customers c on o.customer_id = c.customer_id
)
select * from order_list;

-- Zadanie 2
-- Policz liczbe zamowien zlozonych przez kazdego klienta
with customer_orders as (
    select customer_id, count(*) as total_orders
    from orders
    group by customer_id
)
select c.name, co.total_orders
from customers c
join customer_orders co on c.customer_id = co.customer_id;

-- Zadanie 3
-- Oblicz laczna wartosc (suma) kazdego zamowienia
with order_values as (
    select oi.order_id, sum(oi.quantity * p.price) as total_value
    from order_items oi
    join products p on  oi.product_id = p.product_id
    group by oi.order_id
)
select o.order_id, o.order_date, ov.total_value
from orders o
join order_values ov on o.order_id = ov.order_id;

-- Zadanie 4
-- Oblicz srednia wartosc zamowienia dla kazdego klienta

with
    order_totals as(
    select o.order_id, o.customer_id, sum(oi.quantity * p.price) as total_value
    from orders o
    join order_items oi on o.order_id = oi.order_id
    join products p on p.product_id = oi.product_id
    group by o.order_id, o.customer_id
),
    customer_avg as (
        select customer_id, round(avg(total_value), 2) as avg_order_value
        from order_totals
        group by customer_id
    )
select c.name, ca.avg_order_value
from customers c
join customer_avg ca on c.customer_id = ca.customer_id;

-- Zadanie 5
-- Na podstawie liczby zamowien wyswietl tylko tych klientow, ktorzy dokonali wiecej
-- niz jednej transakcji