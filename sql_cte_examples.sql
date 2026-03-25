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

with customer_order_count as (
    select customer_id, count(*) as order_count
    from orders
    group by customer_id
)
select c.name, coc.order_count
from customers c
join customer_order_count coc on c.customer_id = coc.customer_id
where coc.order_count > 1;

-- Zadanie 6
-- Zidentyfikuj wszystkie produkty, ktore nie wystepuja w zadnym zamowieniu

with order_products as (
    select distinct product_id
    from order_items
)
select p.product_name
from products p
left join order_products op on p.product_id = op.product_id
where op.product_id is null;

-- Zadanie 7
-- Sumuj ilosci produktow ze wszystkich zamowien danego klienta
-- Dla kazdego klienta pokaz laczna liczbe zamowionych sztuk produktow

with customers_items as (
    select o.customer_id, sum(oi.quantity) as total_quantity
    from orders o
    join order_items oi on o.order_id = oi.order_id
    group by o.customer_id
)
select c.name, ci.total_quantity
from customers c
join customers_items ci on c.customer_id=ci.customer_id;

-- Zadanie 8
-- Pokaz szczegoly ostatniego zamowienia kazdego klienta
with
    last_order as (
        select customer_id, max(order_date) as last_date
        from orders
        group by customer_id
),
    order_details as (
        select o.order_id, o.customer_id, o.order_date, c.name
        from orders o
        join customers c on c.customer_id = o.customer_id
    )
select od.*
from order_details od
join last_order lo on od.customer_id=lo.customer_id and od.order_date = lo.last_date;

-- Zadanie 9
-- Pokaz 3 najczesciej zamawiane produkty
-- Sumujemy ilosci kazdego produktu w zamowieniach i pokazujemy top 3

with product_quantity as (
    select product_id, sum(quantity) as total_quantity
    from order_items
    group by product_id
)
select p.product_name, pq.total_quantity
from product_quantity pq
join products p on pq.product_id=p.product_id
order by pq.total_quantity desc
limit 3;

-- Zadanie 10
-- Wyswietl zamowienia, ktorych laczna wartosc przekracza srednia wartosc wszystkich zamowien
-- CTE avg_value zawiera tylko jeden wiersz (średnia wartość), więc chcesz tę wartość dołączyć do każdego wiersza
-- z orders. Zastosowanie on true daje nam tzw. cross joina
-- W tym przypadku czy wybierzemy cross join czy on true bedzie ok, a Ty masz alternatywe w takiej sytuacji.

with order_totals as (
    select order_id, sum(oi.quantity * p.price) as total_value
    from order_items oi
    join products p on p.product_id = oi.product_id
    group by order_id
),
    avg_value as (
        select avg(total_value) as avg_order_value from order_totals
    )
select o.order_id, o.order_date, ot .total_value
from orders o
join order_totals ot on ot.order_id=o.order_id
-- join avg_value av on true
cross join avg_value av
where ot.total_value > av.avg_order_value;

-- Zadanie 11
-- Pokaz produkty, ktore byly zamawiane przez wiecej niz jednego klienta

with
    product_customers as (
        select oi.product_id, o.customer_id
        from order_items oi
        join orders o on oi.order_id = o.order_id
        group by oi.product_id, o.customer_id
),
    product_counts as (
        select product_id, count(*) as unique_customers
        from product_customers
        group by product_id
    )
select p.product_name, pc.unique_customers
from product_counts pc
join products p on pc.product_id=p.product_id
where pc.unique_customers > 1;

--  ====================================================================================================================
--  CTE REKURENCYJNE
--  ====================================================================================================================

--  Zadanie 1
--  Rekurencyjne wyliczenie zamowien - 1 dziennie do najnowszego.
--  Zacznij od najstarszego zamowienia i rekurencyjnie dodawaj kolejne dni, pokazujac, ile zamowien bylo kazdego dnia.

with recursive dates(date) as (
    select min(order_date) from orders
    union all
    select date + interval 1 day
    from dates
    where date + interval 1 day <= (select max(order_date) from orders)
)
select d.date, count(order_id) as order_on_day
from dates d
left join orders o on o.order_date=d.date
group by d.date
order by d.date;

--  Zadanie 2
--  Rekurencyjna eksplozja zamowien klienta dzien po dniu
--  Dla konkretnego klienta wyswietl dzien po dniu historie zamowien, nawet jesli nie zlozyl zamowienia danego dnia

with recursive customer_dates(date) as (
    select min(order_date) from orders where customer_id = 1
    union all
    select date + interval 1 day
    from customer_dates
    where date + interval 1 day <= (select max(order_date) from orders where customer_id  = 1)
)
select cd.date, count(o.order_id) as orders
from customer_dates cd
left join orders o on o.order_date= cd.date and o.customer_id=1
group by cd.date
order by cd.date;

--  Zadanie 3
--  Obliczanie skumulowanej liczby zamowien
--  Liczymy ile lacznie zamowien bylo do danego dnia.

with recursive daily_orders as (
    select min(order_date) as order_date, 0 as total_orders
    from orders
    union all
    select do.order_date + interval 1 day,
           (select count(*) from orders where order_date <= + interval 1 day)
    from daily_orders do
    where do.order_date + interval 1 day <= (select max(order_date) from orders)
)
select * from daily_orders;

with recursive daily_orders as (
    -- Tutaj drobna poprawka, zeby policzyc, ile bylo zamowien w pierwszym dniu

    -- STARA WERSJA
    -- select min(order_date) as order_date, 0 as total_orders
    -- from orders
    -- POWINNO BYC TAK:
    select min(order_date) as order_date, count(*) as total_orders
    from orders
    where order_date = (select min(order_date) from orders)
    union all
    select do.order_date + interval 1 day,
           (select count(*) from orders where order_date <= do.order_date + interval 1 day)
    from daily_orders do
    where do.order_date + interval 1 day  <= (select max(order_date) from orders)
)
select * from daily_orders;

--  Teraz optymalizacja powyzszego zapytania z zapamietaniem tego, co bylo wyliczone do tej pory.
--  order_date      -   dzien ktory wlasnie analizujemy
--  total_orders    -   laczna liczba zamowien do tego dnia
--  Co zyskujemy?
--  Kazdy krok liczy tylko zamowienia z jednego konkretnego dnia
--  Laczna suma jest niemalejaca, bo dodajemy do poprzedniego total_orders

with recursive daily_orders as (
    select min(order_date) as order_date, count(*) as total_orders
    from orders
    where order_date= (select min(order_date) from orders)
    union all
    select do.order_date + interval 1 day,
           do.total_orders + (
               select count(*) from orders where order_date = do.order_date + interval 1 day)
    from daily_orders do
    where do.order_date + interval 1 day <= (select max(order_date) from orders)
)
select * from daily_orders;