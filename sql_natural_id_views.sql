/*
    ----------------------------------------------------------------------------------------------------
    Natural ID (Natural Key)
    ----------------------------------------------------------------------------------------------------
    Natural ID (albo natural key) to kolumna lub zbiór kolumn, które:
    -> są unikalne w kontekście danych biznesowych,
    -> istnieją w rzeczywistości (np. numer PESEL, email, numer VIN),
    -> mogą służyć jako główny identyfikator rekordu,
    -> mają znaczenie poza systemem bazy danych.

    | Właściwość          | Natural ID               | Surrogate ID (`id`)     |
    | ------------------- | ------------------------ | ----------------------- |
    | Znaczenie biznesowe | Ma znaczenie (np. email) | Brak znaczenia          |
    | Czytelność          | Wysoka                   | Niska                   |
    | Łatwość zmiany      | Trudna / ryzykowna       | Brak potrzeby           |
    | Wydajność indeksu   | Może być niższa          | Zwykle wysoka (INT)     |
    | Typ danych          | VARCHAR, DATE, inne      | Zwykle `INT` lub `UUID` |
    | Skalowalność        | Ograniczona              | Bardziej skalowalna     |
*/

CREATE TABLE users (
   email VARCHAR(255) NOT NULL,
   first_name VARCHAR(100),
   last_name VARCHAR(100),
   date_of_birth DATE,
   PRIMARY KEY (email)  -- Natural ID
);

# Tutaj email pełni rolę naturalnego klucza głównego. Oznacza to, że nie możemy mieć dwóch użytkowników
# z tym samym adresem email.

# Mozesz zrobic zlozone natural id.
CREATE TABLE flights (
     flight_number VARCHAR(10) NOT NULL,
     departure_date DATE NOT NULL,
     origin_airport_code CHAR(3),
     destination_airport_code CHAR(3),
     PRIMARY KEY (flight_number, departure_date)
);
# Tutaj klucz naturalny składa się z dwóch kolumn: flight_number i departure_date.

# Kiedy NIE używać naturalnego ID?
# -> Jeśli dane mogą się zmienić (np. nazwisko, email),
# -> Jeśli dane są długie (np. długi opis produktu),
# -> Jeśli nie masz pewności co do unikalności.


/*
    ----------------------------------------------------------------------------------------------------
    Views (widoki)
    ----------------------------------------------------------------------------------------------------

    View to wirtualna tabela, oparta na zapytaniu SELECT. Widok:
    -> nie przechowuje danych fizycznie,
    -> zawsze odświeża dane na bieżąco,
    -> może upraszczać zapytania, ukrywać złożoność i zabezpieczać dane.

    CREATE VIEW view_name AS
    SELECT ...
    FROM ...
    WHERE ...;

    Zalety widoków
    -> Abstrakcja – ukrywa złożoność zapytań.
    -> Bezpieczeństwo – można dać dostęp tylko do widoku.
    -> Ponowne użycie – jedno źródło danych do różnych zapytań.
    -> Czytelność – kod SQL jest czystszy i bardziej zrozumiały.

    Ograniczenia widoków
    -> Nie można tworzyć indeksów na widokach.
    -> Nie każdy widok można aktualizować (np. zawierający GROUP BY, DISTINCT, agregaty).
    -> Może mieć wpływ na wydajność przy złożonych zapytaniach.
*/

CREATE TABLE customers (
   customer_id INT AUTO_INCREMENT PRIMARY KEY,
   email VARCHAR(255) NOT NULL UNIQUE,
   first_name VARCHAR(100),
   last_name VARCHAR(100)
);

CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATE,
    total_amount DECIMAL(10, 2),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

# Prosty widok - tylko aktywne zamowienia
create view recent_orders as
select order_id, customer_id, order_date, total_amount
from orders
where order_date >= curdate() - interval 30 day;



# Abstrakcja i uproszczenie
# Widok ukrywa złożoność. Jeśli ktoś potrzebuje tylko "ostatnich zamówień", nie musi wiedzieć
# jak one są filtrowane – wystarczy użyć widoku.

# Centralne miejsce zmian
# Jeśli zmieni się logika wyznaczania "ostatnich zamówień" (np. 30 dni → 60 dni), wystarczy
# zaktualizować definicję widoku – nie trzeba szukać i zmieniać każdego wystąpienia tego zapytania
# w kodzie.

# Możliwość integracji z innymi zapytaniami
# Widok może być użyty w JOIN-ach, podzapytaniach itp., jakby był tabelą. To pozwala pisać bardziej
# złożone zapytania bez zagnieżdżania długich SELECT-ów.

# Widok sam w sobie nie zwiększa wydajności – to tylko alias dla zapytania. Silnik bazy danych
# i tak rozwija widok do jego definicji przy wykonaniu zapytania (chyba że mówimy o tzw.
# materializowanych widokach – ale to inny temat).

select * from recent_orders;
select order_id, order_date from recent_orders where order_id = 1;

# Widok z join
create view customer_orders as
select
    o.order_id,
    o.order_date,
    o.total_amount,
    c.customer_id,
    c.first_name,
    c.last_name
from orders o
join customers c on o.customer_id = c.customer_id;

# Widok z agregacja
create view total_spent_by_customer as
select customer_id,
       sum(total_amount) as total_spent
from orders
group by customer_id;
select * from total_spent_by_customer;

# Widok reaguje na zmiany w tabelach na podstawie ktorych zostal stworzony.
# Sam widok mozesz aktualizowac, tylko jesli nie zawiera join, group by, distinct, union, limit, order by.

create view cheap_orders as
    select order_id, total_amount
from orders
where total_amount < 50;

update cheap_orders
set total_amount = 49.99
where order_id = 2;

select * from cheap_orders;

# Widok moze dac nam dodatkowa warstwe bezpieczenstwa.
# Nie chcemy, by pracownik miał dostęp do pełnych danych klientów – tylko do widoku:

CREATE VIEW public_customers AS
SELECT first_name, last_name
FROM customers;
-- Użytkownik ma tylko GRANT SELECT ON public_customers

/*
Kiedy warto zastosować widok (view):

-> Aby uprościć złożone zapytania – kiedy masz skomplikowane JOIN, WHERE, GROUP BY, możesz je opakować w widok
i używać jak prostej tabeli.

-> Do wielokrotnego użycia tej samej logiki – jeśli ten sam SELECT jest używany w wielu miejscach, widok eliminuje
powtarzalność.

-> W celu ograniczenia dostępu do danych – widok może udostępniać tylko wybrane kolumny / tabele, zwiększając
bezpieczeństwo.

-> Aby oddzielić warstwę aplikacyjną od struktury danych – jeśli zmieni się struktura bazy, wystarczy zaktualizować
widok, a nie aplikację.

-> Do tworzenia podsumowań i raportów – np. agregacja sprzedaży, statystyki, podsumowania.


Kiedy nie warto stosować widoku:

-> Gdy zależy Ci na wysokiej wydajności – widoki nie przechowują danych, każde użycie powoduje wykonanie zapytania
od nowa.

-> Gdy widok ma być aktualizowalny, ale jest zbyt złożony – jeśli zawiera JOIN, GROUP BY, funkcje agregujące, nie
pozwala na UPDATE lub INSERT.

-> Gdy widoki są głęboko zagnieżdżone – trudne do debugowania, mogą prowadzić do problemów z logiką lub
nieczytelnością kodu.

-> Gdy dane w widoku mają się zmieniać dynamicznie – widoki nie wspierają zmiennych czy dynamicznych warunków.

-> Gdy nadmiar widoków zaciemnia strukturę bazy – zbyt wiele widoków może utrudnić orientację i zarządzanie bazą danych.


Stosuj widoki wtedy, gdy chcesz uprościć dostęp do danych, zwiększyć czytelność i bezpieczeństwo, ale unikaj ich
w przypadkach wymagających maksymalnej wydajności lub edytowalności danych.
*/

/*
    Widok materializowany to specjalny rodzaj widoku, który przechowuje dane fizycznie na dysku, tak jak zwykła
    tabela. W przeciwieństwie do zwykłych (dynamicznych) widoków, które generują wynik na żywo za każdym razem,
    widok materializowany zawiera zrzut (snapshot) wyników zapytania w momencie jego utworzenia lub ostatniej
    aktualizacji.

    Po co stosować widok materializowany?
    -> Przyspieszenie odczytu z bardzo złożonych zapytań.
    -> Zmniejszenie obciążenia bazy – zapytanie nie musi być liczone od nowa.
    -> Raporty lub dashboardy – kiedy dane nie muszą być w 100% aktualne.
*/