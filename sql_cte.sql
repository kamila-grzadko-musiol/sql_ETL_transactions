/*
    -------------------------------------------------------------------------------------------------------------------
    Common Table Expressions (CTE)
    -------------------------------------------------------------------------------------------------------------------

    CTE (Common Table Expression) to tymczasowy, nazwany zestaw wyników zapytania SQL, który można traktować jak
    tymczasową tabelę lub widok. Został wprowadzony w MySQL od wersji 8.0. CTE pozwala na:
    ->  zwiększenie czytelności i modularności zapytań SQL,
    ->  tworzenie rekurencyjnych zapytań (np. do pracy z hierarchiami),
    ->  dzielenie złożonych operacji SQL na logiczne etapy,
    ->  uniknięcie wielokrotnego powtarzania tych samych fragmentów kodu SQL.

    Skladnia CTE:

    WITH cte_name AS (
        SELECT ...
    )
    SELECT ...
    FROM cte_name;

    Możesz też zdefiniować wiele CTE:

    WITH cte1 AS (
        SELECT ...
    ),
    cte2 AS (
        SELECT ...
    )
    SELECT ...
    FROM cte1
    JOIN cte2 ON ...;

    Rodzaje CTE:
    ->  Nierekurencyjne	    Prosta definicja CTE, działająca jak alias do podzapytania
    ->  Rekurencyjne	    Używana do operacji rekurencyjnych (np. hierarchie, drzewa)

    Zalety używania CTE
    ->  Poprawia czytelność i strukturę kodu
    ->  Umożliwia rekurencję (np. dla struktur drzewiastych)
    ->  Eliminuje konieczność używania podzapytań zagnieżdżonych
    ->  Może pomóc w debugowaniu zapytań SQL
    ->  Łatwiejsza modyfikacja i konserwacja zapytań

    -------------------------------------------------------------------------------------------------------------------
    Przyklad 1 - Wyciagniecie zamowien z ostatnich 30 dni
    -------------------------------------------------------------------------------------------------------------------
*/

create table orders(
    id int primary key auto_increment,
    customer_id int,
    total decimal(10,2),
    created_at date
);

insert into orders(customer_id, total, created_at)
values (1, 200, '2026-03-16'),
       (1, 200, '2026-03-16'),
       (2, 300, '2026-01-16'),
       (2, 300, '2026-01-16'),
       (3, 400, '2026-03-16'),
       (3, 400, '2026-03-16');

with recent_orders as(
    select *
    from orders
    where created_at >= curdate() - interval 30 day
)
select customer_id, count(*) as total_orders, sum(total) as total_amount
from recent_orders
group by customer_id;


/*
    -------------------------------------------------------------------------------------------------------------------
    Przykład 2 - Łączenie wielu CTE
    -------------------------------------------------------------------------------------------------------------------
*/

with recent_orders as (
    select * from
    orders
    where created_at >= curdate() - interval 30 day
),
    high_value_orders as (
        select * from recent_orders where total > 300
    )
select * from high_value_orders;

/*
    -------------------------------------------------------------------------------------------------------------------
    Przyklad 3 - Unikanie powtarzania zapytan
    -------------------------------------------------------------------------------------------------------------------
*/
-- Bez CTE mamy zdublikowane zapytanie

select avg(total)
from (
    select * from orders where created_at >= curdate() - interval 30 day
) as temp;

-- CTE

with recent_orders as(
    select * from orders where created_at >= curdate() - interval 30 day
)
select avg(total) from recent_orders;

/*
    Zduplikowanie zapytania polega na wielokrotnym powtarzaniu tego samego fragmentu SQL (np. podzapytania SELECT,
    filtrów WHERE, itp.) w różnych miejscach tego samego zapytania – często dlatego, że brakuje mechanizmu, który
    pozwoliłby raz zdefiniować dany fragment i potem go wielokrotnie użyć.

    select avg(total)
    from (
        select * from orders where created_at >= curdate() - interval 30 day
    ) as temp;

    Mamy w tym zapytaniu warunek:
    select * from orders where created_at >= curdate() - interval 30 day
    jest „zagnieżdżony” w podzapytaniu. Gdybyś potrzebował tego samego warunku w wielu miejscach (np. w AVG, COUNT, SUM,
    JOIN, itp.), musiałbyś go powtarzać ręcznie. To właśnie jest zduplikowanie zapytania: kopiowanie tego samego kodu
    SQL zamiast jego ponownego użycia.

    Kiedy masz CTE:
    with recent_orders as (
        select * from orders where created_at >= curdate() - interval 30 day
    )
    select avg(total) from recent_orders;
    Tutaj tworzysz CTE recent_orders, czyli tymczasową nazwę (jakby widok) na jedno zapytanie. Możesz teraz używać
    recent_orders wielokrotnie, bez ponownego pisania warunku.

    ->  Unikasz powtarzania kodu (redukcja duplikacji)
    ->  Poprawiasz czytelność
    ->  Ułatwiasz utrzymanie kodu – zmieniasz warunek w jednym miejscu
    ->  Możesz używać rekurencji (np. do hierarchii) – zaawansowane przypadki

    -------------------------------------------------------------------------------------------------------------------
    Zauwaz, ze wiele razy, kiedy tworze CTE uzywalem tej samej nazwy reverse_orders. Czy to podejscie dobre
    i czy tak mozna?
    -------------------------------------------------------------------------------------------------------------------

    ->  Tak, możesz tak robić, jeśli każde zapytanie działa niezależnie i CTE o tej samej nazwie nie występują w
        jednym WITH-bloku.

    ->  Jeśli masz oddzielne zapytania SQL, np. w różnych plikach, zapytaniach ad hoc, testach, itp., i w każdym
        z nich tworzysz reverse_orders, np.:
        with reverse_orders as (
            select * from orders order by created_at desc
        )
        select * from reverse_orders;
        To absolutnie OK, że używasz tej samej nazwy – CTE działa lokalnie w ramach jednego zapytania i nie ma wpływu
        na inne zapytania.

    ->  Jeśli piszesz bardzo duży plik z wieloma CTE i przypadkowo użyjesz tej samej nazwy dwukrotnie w tym samym bloku,
        np.:
        with reverse_orders as (...),
        reverse_orders as (...) -- konflikt!
        select * from reverse_orders;
        To SQL wyrzuci błąd – nie możesz zdefiniować dwóch CTE o tej samej nazwie w tym samym bloku.

    ->  Nazwa CTE dobrze zeby odwzorowywala jej przeznaczenie / zastosowanie.
    ->  Niektóre zespoły ustalają konwencje nazw dla CTE, np. cte_reverse_orders, żeby łatwo je odróżnić od zwykłych
        tabel.

    -------------------------------------------------------------------------------------------------------------------
    Jak ma sie CTE do komunikacji z aplikacja napisana np. w Python, Java, JS, C++
    -------------------------------------------------------------------------------------------------------------------

    CTE są tymczasowe i lokalne dla pojedynczego zapytania.
    ->  Nie istnieją w bazie danych po zakończeniu wykonania zapytania. To znaczy, że:
        ->  Nie możesz się do nich odwołać z innego zapytania
        ->  Nie widać ich z poziomu aplikacji jako „tabel”
        ->  Musisz za każdym razem dołączać WITH ... w zapytaniu

    -------------------------------------------------------------------------------------------------------------------
    Porownanie CTE vs subqueries vs widoki vs tabele
    -------------------------------------------------------------------------------------------------------------------

    Tabela (TABLE)
    ->  Fizyczna struktura w bazie danych.
    ->  Przechowuje dane na stałe (na dysku).
    ->  Możesz wykonywać zapytania, modyfikować, kasować, indeksować itd.
    ->  Trwała – dane nie znikają po zakończeniu zapytania.
    ->  Może być modyfikowana (INSERT, UPDATE, DELETE).
    ->  Widoczna globalnie w całej bazie danych.
    ->  Używaj, gdy:
        ->  Przechowujesz dane biznesowe lub operacyjne.
        ->  Chcesz indeksować dane.
        ->  Wiele aplikacji ma korzystać z tych samych danych.
        ->  Inne oczywiste zastosowania

    Widok (VIEW)
    ->  Wirtualna tabela utworzona na podstawie zapytania.
    ->  Sama nie przechowuje danych – działa jak „alias” na SELECT.
    ->  Trwała (dopóki jej nie usuniesz).
    ->  Działa jak tabela w zapytaniach (SELECT z widoku).
    ->  Może ukrywać złożoność zapytań.
    ->  Nie wszystkie widoki są edytowalne (updatable).
    ->  Reaguje na zmiany w powiaznych tabelach
    ->  Używaj, gdy:
        ->  Chcesz uprościć skomplikowane zapytania.
        ->  Potrzebujesz warstwy abstrakcji nad danymi.
        ->  Współdzielisz dane między aplikacjami, ale chcesz ukryć szczegóły.

    Podzapytanie (Subquery)
    ->  Zapytanie zagnieżdżone w innym zapytaniu (SELECT, WHERE, FROM, IN, itd.).
    ->  Tymczasowe i tylko lokalne.
    ->  Może być zagnieżdżone w SELECT, WHERE, JOIN, FROM itd.
    ->  Może być korelowane (odwołuje się do zewnętrznego zapytania) lub nie.
    ->  Używaj, gdy:
        ->  Potrzebujesz jednorazowego filtrowania lub transformacji.
        ->  Nie potrzebujesz ponownego użycia tego samego zapytania.
        ->  Chcesz pisać krótkie zapytania inline.
        ->  Niekiedy powtorzysz fragment "sql"
        ->  Sa niewygodne

    CTE (WITH – Common Table Expression)
    ->  Tymczasowy „alias” dla zapytania, zdefiniowany na początku.
    ->  Można zdefiniować wiele CTE.
    ->  Istnieje tylko w ramach jednego zapytania.
    ->  Lokalna i tymczasowa (jak subquery).
    ->  Często bardziej czytelna niż podzapytania.
    ->  Może być rekurencyjna (zaraz o tym powiemy).
    ->  Nie można modyfikować (jak widok).
    ->  Używaj, gdy:
        ->  Masz złożone zapytania, które warto podzielić na logiczne części.
        ->  Chcesz wielokrotnie użyć tego samego zbioru danych (w ramach zapytania).
        ->  Chcesz uniknąć powtarzania zapytań (redukcja duplikacji).
        ->  Potrzebujesz rekurencji.

    Kiedy uzywac czego?

    --------------------------------------------------------------------------------------------------------------
    | Sytuacja                                                                          | Użyj                   |
    | --------------------------------------------------------------------------------- | ---------------------- |
    | Chcesz przechowywać dane trwałe                                                   | **Tabela**             |
    | Chcesz uprościć złożone zapytania do ponownego użycia                             | **Widok**              |
    | Masz skomplikowane zapytanie jednorazowe, chcesz podzielić na logiczne bloki      | **CTE**                |
    | Potrzebujesz szybkiego filtru / jednorazowego zapytania w `SELECT`, `WHERE`, itd. | **Podzapytanie**       |
    | Potrzebujesz rekurencji (np. drzewa, hierarchie)                                  | **CTE (rekurencyjne)** |
    --------------------------------------------------------------------------------------------------------------

    -------------------------------------------------------------------------------------------------------------------
    CTE Rekurencyjne
    -------------------------------------------------------------------------------------------------------------------
    To CTE, które wywołuje samą siebie. Przydatne np. do:
    ->  drzew (np. kategorie, foldery, hierarchie),
    ->  grafów (np. zależności),
    ->  generowania ciągów (np. daty, liczby).

    WITH RECURSIVE cte_name AS (
        -- Część kotwicząca (anchor)
        SELECT ...
        UNION ALL
        -- Część rekurencyjna
        SELECT ...
        FROM cte_name
        JOIN ... ON ...
    )
    SELECT * FROM cte_name;
*/

create table empployees (
    id int primary key auto_increment,
    name varchar(50),
    manager_id int
);

insert into empployees (name, manager_id) values
('Anna(CEO)', null),
('Bartek(CTO)', 1),
('Celina(CFO)', 1),
('Daniel(Dev)', 2),
('Ewa(Dev)', 2),
('Franek(Finance)', 3),
('Grzegorz(Intern)', 4);

select * from empployees;

/*
    Anna (CEO)
    ├── Bartek (CTO)
    │   ├── Daniel (Dev)
    │   │   └── Grzegorz (Intern)
    │   └── Ewa (Dev)
    └── Celina (CFO)
        └── Franek (Finance)
*/

-- Rekurencyjne CTE - employee_hierarchy

with recursive employee_hierarchy as (
    -- Czesc kotwiczaca
    -- Znajduje korzeń drzewa – osoby bez przełożonych (np. CEO).
    -- Zaczynamy od najwyzszego szczebla
    select id, name, manager_id
    from empployees
    where manager_id is null

    union all

    -- Czesc rekurencyjna
    -- Wyszukuje podwładnych aktualnie znalezionych osób.
    -- Łączy się rekurencyjnie z wynikiem poprzedniego kroku
    -- (employee_hierarchy), żeby znaleźć dzieci tych węzłów.
    select e.id, e.name, e.manager_id
    from empployees e
    inner join employee_hierarchy eh on e.manager_id = eh.id
)
select * from employee_hierarchy;

-- Zeby zrobic jeszcze bardziej "zaawansowany" pokaz mozliwosci dodamy:
-- ->   kolumne level, ktora pokaze na ktorym poziomie w hierarchii ktos sie znajduje
-- ->   sciezke tekstowa Anna -> Bartek -> Daniel
-- ->   Formatowanie zeby pokazac strukture drzewa wizualnie

with recursive employee_hierarchy as (
    select
        id,
        name,
        manager_id,
        0 as level,
        cast(name as char(1000)) as path
    from empployees
    where manager_id is null

    union all

    select
        e.id,
        e.name,
        e.manager_id,
        eh.level + 1 as level,
        concat(eh.path, ' -> ', e.name) as path
    from empployees e
    inner join employee_hierarchy eh on e.manager_id = eh.id

)
select
    id,
    concat(lpad(' ', level * 4, ' '), name) as indent_name,
    level,
    path
from employee_hierarchy
order by path;

/*
    -------------------------------------------------------------------------------------------------------------------
    Przyklad - generowanie dat
    -------------------------------------------------------------------------------------------------------------------
*/
with recursive calendar as(
    select date ('2025-01-01') as date_val
    union all
    select date_add(date_val, interval 1 day)
    from calendar
    where date_val < '2025-01-31'
)
select * from calendar;

/*
    -------------------------------------------------------------------------------------------------------------------
    Podsumowanie i jeszcze kilka informacji na temat CTE
    -------------------------------------------------------------------------------------------------------------------

    ->  Domyślny limit rekurencji to 1000 – można zmienić przez SET @@cte_max_recursion_depth.
    ->  CTE są tymczasowe – nie można ich użyć do UPDATE, INSERT (chyba że używasz ich z WITH w MERGE, INSERT ... SELECT itd.).
    ->  Nie ma indeksów na CTE – są przechowywane w pamięci jako tymczasowy wynik.
    ->  W wielu przypadkach CTE są mniej wydajne niż podzapytania, bo niektóre silniki nie optymalizują ich dobrze.
    ->  W MySQL CTE są materializowane (czyli przetwarzane raz) — niektóre wersje mogą nie zoptymalizować ich powtórnego
        użycia.

    WITH top_customers AS (
        SELECT customer_id, SUM(total) AS total_spent
        FROM orders
        GROUP BY customer_id
        HAVING total_spent > 10000
    )
    DELETE FROM customers
    WHERE id IN (SELECT customer_id FROM top_customers);

    CTE jako "etapy przetwarzania"

    Zamiast pisac dlugie zapytanie zagniezdzone:
    SELECT ...
    FROM (
        SELECT ...
        FROM (
            SELECT ...
        ) AS step1
    ) AS step2;

    Mozesz napisac:
    WITH
    step1 AS (SELECT ...),
    step2 AS (SELECT ... FROM step1),
    step3 AS (SELECT ... FROM step2)
    SELECT * FROM step3;

    Dobre praktyki
    ->  Nadaj czytelne nazwy CTE (orders_last_month, employee_hierarchy, calendar_dates)
    ->  Używaj CTE do modularnego budowania zapytań
    ->  Unikaj zagnieżdżania zbyt wielu poziomów rekurencji
    ->  Testuj wydajność (czasami CTE są wolniejsze niż JOIN-y i podzapytania)
    ->  Dokumentuj skomplikowane rekurencje

*/
