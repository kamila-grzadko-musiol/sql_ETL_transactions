/*
    Procedury Składowane (Stored Procedures)
    Procedura składowana to predefiniowany blok kodu SQL (czasem z elementami logiki proceduralnej), zapisany
    bezpośrednio w bazie danych, który można wywołać wielokrotnie w celu wykonania zestawu operacji. Jest ona
    składowana na serwerze bazy danych i wykonywana tam, co eliminuje potrzebę przesyłania wielokrotnie tych samych
    instrukcji z aplikacji.

    ->  Nie musi zwracać wartości, choć może zwracać dane poprzez parametry OUT lub kursory.
    ->  Obsługuje logikę proceduralną: instrukcje warunkowe (IF), pętle (WHILE, FOR), bloki BEGIN...END.
    ->  Może modyfikować dane (INSERT, UPDATE, DELETE).
    ->  Może obsługiwać transakcje (BEGIN TRANSACTION, COMMIT, ROLLBACK).
    ->  Parametry wejściowe: IN, OUT, INOUT.
    ->  Może wywoływać inne procedury i funkcje.
    ->  Zapisana w bazie – można ją kontrolować wersjonowaniem i prawami dostępu.

    Jakie korzysci mamy, kiedy uzywamy procedury skladowane?
    ->  Centralizacja logiki biznesowej – logika przechowywana w jednym miejscu, a nie rozproszona po kodzie
        aplikacji.
    ->  Oszczędność czasu i pasma sieciowego – kod SQL nie musi być przesyłany za każdym razem.
    ->  Bezpieczeństwo – można nadać dostęp do procedury bez bezpośredniego dostępu do tabel.
    ->  Optymalizacja i caching – silniki baz danych mogą zoptymalizować wykonanie kodu procedury.
*/


create table customers (
    id int primary key auto_increment,
    name varchar(100),
    email varchar(100)
);

create table products (
    id int primary key auto_increment,
    name varchar(100),
    price decimal(10, 2)
);

create table cart_items (
    id int primary key auto_increment,
    cart_id int not null,
    product_id int not null,
    quantity int not null,
    price decimal(10, 2) not null,
    foreign key (product_id) references products(id)
);

create table orders (
    id int primary key auto_increment,
    customer_id int not null,
    total decimal(10, 2) not null,
    status varchar(50) not null,
    created_at datetime not null,
    foreign key (customer_id) references customers(id)
);

create table order_items (
    id int primary key auto_increment,
    order_id int not null,
    product_id int not null,
    quantity int not null,
    price decimal(10, 2) not null,
    foreign key (order_id) references orders(id),
    foreign key (product_id) references products(id)
);

create table user_roles (
    id int primary key auto_increment,
    user_id int not null,
    role_name varchar(50) not null,
    unique key unique_user_role (user_id, role_name),
    foreign key (user_id) references customers(id)
);

INSERT INTO customers (id, name, email) VALUES (100, 'Jan Kowalski', 'jan@example.com');
INSERT INTO products (id, name, price) VALUES
    (1, 'Produkt A', 25.00),
    (2, 'Produkt B', 50.00);
INSERT INTO cart_items (cart_id, product_id, quantity, price) VALUES
    (1, 1, 2, 25.00),
    (1, 2, 1, 50.00);
INSERT INTO user_roles (user_id, role_name) VALUES (100, 'user');

-- Pierwsza procedura skladowana utworzy kompletna logike zamowienia
-- -> transakcja
-- -> kopiowanie danych
-- -> czyszczenie koszyka
-- Jedna procedura realizujaca spojnosc danych.

--  Mamy 3 rodzaje parametrow:

--  ->  IN
--      ->  Przekazujesz wartość do procedury.
--      ->  Wartość nie może być modyfikowana wewnątrz procedury (zmiana jest lokalna).

--  ->  OUT
--      ->  Używany do zwracania wartości na zewnątrz procedury.
--      ->  Można ustawić go wewnątrz procedury (np. SET p_out = ...).

--  ->  INOUT
--      ->  Przekazujesz wartość do procedury i możesz ją zmienić – wynik wraca po zakończeniu.
--      ->  Klasycznym pzykladem jest tutaj parametr, ktory jest licznikiem, chcesz go odczytac a zarazem
--          kiedy zajda pewne warunki lub tak po prostu po wykonaniu ciala procedury zwiekszyc o 1


create procedure process_order (
    IN p_customer_id int,
    IN p_cart_id int,
    OUT p_order_id int
)
begin
    declare total_amount decimal(10, 2);

    start transaction;

    -- Oblicz wartosc zamowienia
    select sum(price * quantity) into total_amount
    from cart_items where cart_id = p_cart_id;

    -- Utworz rekod zamowienia
    insert into orders (customer_id, total, status, created_at)
        values (p_customer_id, total_amount, 'processing', now());

    -- Ustawiamy parametr out o nazwie p_order_id na id ostatnio wstawionym
    set p_order_id = last_insert_id();

    -- Skopiuj pozycje z koszyka do pozycji zamowienia
    insert into order_items (order_id, product_id, quantity, price)
    select p_order_id, product_id, quantity, price
    from cart_items where cart_id = p_cart_id;

    -- Wyczysc koszyk
    delete from cart_items where cart_id=p_cart_id;

    commit;
end;

-- W ten sposob wywolujesz procedure skladowana
call process_order(100, 1, @new_order_id);
select @new_order_id;

-- Ponizej procedura, ktora umozliwia nadawanie uprawnien uzytownikom
create procedure grant_role_to_user(
    in p_user_id int,
    in p_role_name varchar(50)
)
begin
    if not exists(
        select 1 from user_roles where user_id = p_user_id and role_name = p_role_name
    ) then
        insert into user_roles (user_id, role_name) values (p_user_id, p_role_name);
    end if;
end;

call grant_role_to_user(100, 'admin');

create procedure demo_all_types_of_params(
    in p_input int,
    out p_output int,
    inout p_inout int
)
begin
    set p_input = p_input * 2; -- @x - 10
    set p_output = p_input * 2; -- @y - 40
    set p_inout = p_input + p_input; -- @z - 60
end;

set @x = 10;
set @y = 20;
set @z = 30;
call demo_all_types_of_params(@x, @y, @z);
select @x;
select @y;
select @z;