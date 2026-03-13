/*
     Co to jest trigger w MySQL?
     Trigger (czyli wyzwalacz) w MySQL to specjalny obiekt bazodanowy, który automatycznie wykonuje się w odpowiedzi
     na określone zdarzenie (INSERT, UPDATE, DELETE) na danej tabeli. Trigger działa jak reakcja, która uruchamia
     się zawsze, gdy wykonana zostanie operacja na tabeli — np. dodanie nowego rekordu lub jego modyfikacja.

     Kiedy używać triggerów?
        ->  Gdy chcesz automatycznie uzupełniać dane (np. datę modyfikacji).
        ->  Do logowania operacji (np. kto i kiedy zmienił dane).
        ->  Do kontroli integralności danych, której nie da się wyrazić prostym kluczem obcym.
        ->  Aby automatycznie modyfikować dane w innych tabelach.

     Skladnia CREATE TRIGGER

        CREATE TRIGGER trigger_name
        {BEFORE | AFTER} {INSERT | UPDATE | DELETE}
        ON table_name
        FOR EACH ROW
        BEGIN
            -- ciało triggera, czyli kod SQL
        END;

        ->  trigger_name – nazwa triggera.
        ->  BEFORE lub AFTER – kiedy trigger ma się wykonać:
        BEFORE: przed wykonaniem operacji,
        AFTER: po wykonaniu operacji.
        ->  INSERT | UPDATE | DELETE – typ zdarzenia, które aktywuje trigger.
        ->  table_name – tabela, do której przypisany jest trigger.
        ->  FOR EACH ROW – oznacza, że trigger uruchomi się osobno dla każdego wiersza objętego operacją.

     Specjalne pseudotabele: NEW i OLD
     W triggerach używamy dwóch specjalnych słów:
     -> NEW.column_name – nowa wartość kolumny (np. przy INSERT lub UPDATE)
     -> OLD.column_name – stara wartość kolumny (np. przy UPDATE lub DELETE)
*/

/*
    --------------------------------------------------------------------------------------------------------------------
    Zarzadzanie informacja o dacie wstawiania i modyfikacji
    --------------------------------------------------------------------------------------------------------------------
*/

create table users (
    id int primary key auto_increment,
    username varchar(50),
    created_at datetime,
    updated_at datetime
);

create trigger before_insert_users
    before insert on users
    for each row
    begin
        set NEW.created_at = now();
        set NEW.updated_at = now();
    end;

create trigger before_update_users
    before update on users
    for each row
    begin
        set NEW.updated_at = now();
    end;

insert into users(username)
values ('u'), ('a'), ('ua');

select * from users;

update users set username = concat(username, '2') where id between 1 and 3;

/*
    --------------------------------------------------------------------------------------------------------------------
    Logowanie zmian w tabeli
    --------------------------------------------------------------------------------------------------------------------
*/

create table products (
    id int primary key auto_increment,
    name varchar(100),
    price decimal(10,2)
);

create table product_logs(
    id int auto_increment primary key,
    product_id int,
    old_price decimal(10,2),
    new_price decimal(10,2),
    changed_at datetime,
    foreign key (product_id) references products(id) on delete cascade on update cascade
);

-- Gdy zmieni się cena produktu trigger zapisze starą cene i nową cenę oraz czas tej zmiany
create trigger after_update_products
    after update on products
    for each row
    begin
        if OLD.price != NEW.price then
            insert into product_logs(product_id, old_price, new_price, changed_at)
                values (OLD.id, OLD.price, NEW.price, now());
        end if;
    end;

insert into products(name, price)
values ('product A', 100), ('product B', 200), ('product C', 300);

update products set name = 'Product AA' where id = 1;
update products set name = concat(name, '1'), price = price + 1 where id in (1,2);

select * from products;
select * from product_logs;

/*
    --------------------------------------------------------------------------------------------------------------------
    Synchronizacja dwoch tabel
    --------------------------------------------------------------------------------------------------------------------
*/

create table orders(
    id int primary key auto_increment,
    order_number varchar(20),
    customer_id int,
    total decimal(10,2)
);

create table order_summery(
    order_id int,
    summery_text text,
    foreign key (order_id) references orders(id) on delete cascade on update cascade
);

-- Po dodatniu nowego zamowienia, automatycznie trzwoy sie podsumowanie tekstowe w drugiej tab

create trigger after_insert_orders
    after insert on orders
    for each row
    begin
        insert into order_summery(order_id, summery_text)
            values (NEW.id, concat('Order for customer ', NEW.customer_id, 'with total ', NEW.total));
    end;

insert into orders(order_number, customer_id, total)
values ('Order 1', 1, 100), ('Order 2', 2, 200);

select * from orders;
select * from order_summery;

/*
    --------------------------------------------------------------------------------------------------------------------
    Trigger z walidacja i anulowaniem operacji
    --------------------------------------------------------------------------------------------------------------------

    MySQL pozwala przerwac operacje, rzucajac wyjatek w BEFORE triggerze
*/

create table accounts(
    id int primary key auto_increment,
    balance decimal(10,2)
);

-- Jesli ktos probuje ustawic ujemne saldo, operacja jest anulowana, a uzytkownik dostaje blad
create trigger prevent_negative_balance_on_insert
    before insert on accounts
    for each row
    begin
        if NEW.balance < 0 then
            signal sqlstate '45000'
            set message_text = 'Balance cannot be negative';
        end if;
    end;

create trigger prevent_negative_balance_on_update
    before update on accounts
    for each row
    begin
        if NEW.balance < 0 then
            signal sqlstate '45000'
            set message_text = 'Balance cannot be negative';
        end if;
    end;



insert into accounts(balance) values (10);
insert into accounts(balance) values (-10);
update accounts set balance = -10 where id =1;
select * from accounts;

-- Możesz podejrzeć triggers
show triggers;

-- Usuwanie triggera jesli istnieje
drop trigger if exists prevent_negative_balance;

-- Co to jest signal, co to jest sqlstate i jakie mamy sqlstate?

/*
    SIGNAL to instrukcja służąca do ręcznego wywoływania błędu w MySQL. Można jej użyć w triggerach, procedurach,
    funkcjach lub blokach BEGIN...END, aby przerwać wykonanie i zgłosić niestandardowy błąd.

    signal sqlstate '45000'
    set message_text = 'Balance cannot be negative';
    To rzuca wyjątek (błąd), który można przechwycić w aplikacji. Użytkownik otrzyma komunikat błędu.

    SQLSTATE to kod błędu SQL zgodny z międzynarodowym standardem (ISO/ANSI SQL). Ma postać 5-znakowego ciągu:
    ->  Dwa pierwsze znaki: klasa błędu
    ->  Trzy kolejne znaki: podkategoria (subcode)
    Przykład:
    '45000' – ogólny błąd zdefiniowany przez użytkownika
    '23000' – naruszenie ograniczeń (np. klucza unikalnego)
    '42000' – błąd składni lub uprawnień
    '22012' – dzielenie przez zero

    Najczesciej uzywane SQLSTATE:
    | Kod     | Znaczenie                                                |
    | ------- | -------------------------------------------------------- |
    | `45000` | Błąd użytkownika (używany z `SIGNAL`, dowolny komunikat) |
    | `23000` | Naruszenie ograniczenia (np. UNIQUE, FOREIGN KEY)        |
    | `22001` | Przekroczenie długości danych (np. zbyt długi string)    |
    | `22003` | Przekroczenie zakresu liczbowego                         |
    | `22012` | Dzielenie przez zero                                     |
    | `42000` | Błąd składni SQL lub brak uprawnień                      |
    | `HY000` | Błąd ogólny (catch-all, "coś poszło nie tak")            |

    W naszym przypadku zobaczylismy:
    [45000][1644] Balance cannot be negative
    [1644] — Numer błędu MySQL (MySQL Error Code)
    To wewnętrzny numer błędu MySQL odpowiadający SIGNAL ... SQLSTATE '45000'.
    Kod 1644 to: ER_SIGNAL_EXCEPTION — standardowy kod MySQL dla błędów SIGNAL.
    Nie musisz go ustawiać ręcznie — gdy używasz SIGNAL SQLSTATE '45000', MySQL automatycznie przypisuje mu 1644.

    | Część                        | Znaczenie                                            |
    | ---------------------------- | ---------------------------------------------------- |
    | `45000`                      | SQLSTATE – błąd użytkownika (`SIGNAL`)               |
    | `1644`                       | Kod błędu MySQL dla `SIGNAL` (`ER_SIGNAL_EXCEPTION`) |
    | `Balance cannot be negative` | Twój komunikat błędu                                 |

    Kody błędów MYSQL:
    https://dev.mysql.com/doc/connector-j/en/connector-j-reference-error-sqlstates.html?utm_source=chatgpt.com
    https://dev.mysql.com/doc/mysql-errors/8.0/en/


*/
-- Czy lepiej walidowac dane na:
--  a. frontendzie
--  b. backendzie
--  c. w triggerze w db?

/*
     Frontend (np. JS, React, HTML5)
     -> Szybkość – natychmiastowy feedback dla użytkownika
     -> Lepsze UX (np. pokazanie błędu bez reloadu)
     -> Łatwe do obejścia (devtools, curl, Postman)
     -> Nie gwarantuje bezpieczeństwa
     -> Wstępna walidacja
     -> UX (użytkownik widzi błędy od razu)

     Backend (np. Node.js, Java, Python)
     -> Możliwość dokładnej walidacji
     -> Pełna kontrola nad logiką biznesową
     -> Obsługa wyjątków
     -> Można pominąć przez błędy deweloperskie
     -> Powtarzanie logiki (jeśli jest też w bazie)
     -> Główna warstwa walidacji
     -> Obsługa błędów i reguł biznesowych

     Trigger / Constraint w DB
     -> Nie do obejścia
     -> Działa nawet poza aplikacją (np. ręczny SQL)
     -> Chroni dane na 100%
     -> Trudniejszy debug
     -> Może komplikować bazę i utrudniać migracje
     -> Brak łatwej obsługi błędów
     -> Ostateczna linia obrony
     -> Integralność danych

     Najlepsze podejscie:

     -> Frontend
        Sprawdź pola (czy liczba, czy niepuste, czy nieujemne saldo itp.)
        Informuj użytkownika przed wysłaniem danych

     -> Backend
        Sprawdź dane dokładnie (czy użytkownik ma dostęp, czy wartość pasuje do logiki)
        Zweryfikuj dane zanim trafią do bazy

     -> Baza danych (trigger lub CHECK)
        Waliduj rzeczy, które muszą być absolutnie spójne, niezależnie od aplikacji
        Przykłady:
        ->  balance >= 0
        ->  quantity >= 0
        ->  email IS NOT NULL

     Przykladowe sytuacje:
     Format e-maila	                    Frontend + Backend
     Czy saldo nie jest ujemne	        Backend + Trigger/CHECK
     Czy użytkownik ma uprawnienia	    Backend
     Czy pole nie jest puste	        Frontend + Backend
     Czy FK istnieje	                Baza (FOREIGN KEY)
*/

/*
    Jakie elementy poza if oraz operatorami relacji moga pojawiac sie w ciele triggera czyli pomiedzy
    begin oraz end?

    W ciele triggera MySQL, czyli pomiędzy BEGIN a END, możesz używać wielu różnych elementów języka SQL
    oraz elementów języka proceduralnego (tzw. SQL/PSM).

    ->  Instrukcje przypisujące (SET)
    Używane do przypisywania wartości do zmiennych (np. NEW, zmiennych lokalnych).
    SET NEW.updated_at = NOW();
    SET @counter = @counter + 1;

    ->  Instrukcje warunkowe IF ... THEN ... ELSE
    IF NEW.status = 'cancelled' THEN
        SET NEW.refund_amount = NEW.total_amount;
    ELSEIF NEW.status = 'returned' THEN
        SET NEW.refund_amount = NEW.total_amount * 0.9;
    ELSE
        SET NEW.refund_amount = 0;
    END IF;

    ->  Pętle (WHILE, REPEAT, LOOP)
    Co prawda w triggerach rzadko się używa pętli, ale są dozwolone. Mogą być przydatne przy przetwarzaniu
    sekwencyjnym.

    -- DECLARE: służy do zadeklarowania zmiennej lokalnej (np. wewnątrz procedury lub triggera).
    -- i INT: to zmienna typu całkowitego (INTEGER).
    -- DEFAULT 1: domyślna wartość startowa to 1.
    -- Ta zmienna będzie potem używana np. jako licznik pętli.
    DECLARE i INT DEFAULT 1;
    WHILE i <= 5 DO
        -- jakaś operacja
        SET i = i + 1;
    END WHILE;
    Uwaga: żeby używać pętli, musisz też stosować DECLARE i LEAVE, więc trigger staje się bardziej złożony.

    LEAVE służy do przerwania (wyjścia z) pętli lub bloku oznaczonego etykietą (label). Trochę jak break
    w innych językach.
    W MySQL, aby stosować pętle (WHILE, LOOP, REPEAT), musisz pisać je w oznaczonym bloku, jeśli chcesz przerwać
    ich działanie warunkowo przy użyciu LEAVE.

    DECLARE i INT DEFAULT 1;
    my_loop: WHILE i <= 5 DO
        IF i = 3 THEN
            LEAVE my_loop;  -- przerywa pętlę, jak `break`
        END IF;

        -- jakaś operacja
        SET i = i + 1;
    END WHILE;

    ->  Instrukcje CASE
    SET NEW.discount = CASE
        WHEN NEW.total > 500 THEN 0.2
        WHEN NEW.total > 100 THEN 0.1
        ELSE 0
    END;

    ->  Możesz pobierać dane z innych tabel do zmiennych.
    DECLARE base_salary DECIMAL(10,2);
    SELECT salary INTO base_salary FROM employees WHERE id = NEW.employee_id;

    ->  Funkcje wbudowane (np. NOW(), CONCAT(), UUID())
    SET NEW.created_at = NOW();
    SET NEW.reference = CONCAT('ORD-', UUID());

    ->  Ograniczenia w triggerach
        ->  Nie możesz wykonywać zapytań SELECT bez INTO.
        ->  Nie możesz używać COMMIT, ROLLBACK ani START TRANSACTION.
        ->  Nie możesz tworzyć/dodawać tabel dynamicznie (CREATE TABLE).
        ->  Nie można używać CURSOR (choć technicznie obsługiwane, w praktyce niestabilne w triggerach).


*/