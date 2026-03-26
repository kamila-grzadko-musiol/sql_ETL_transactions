/*
    Temporary tables
    Tymczasowa tabela (ang. TEMPORARY TABLE) to tabela tworzona w MySQL, która:
    ->  istnieje tylko w czasie trwania jednej sesji (połączenia z bazą danych),
    ->  jest widoczna tylko dla użytkownika, który ją stworzył,
    ->  jest automatycznie usuwana po zamknięciu połączenia lub sesji (chyba że usuniesz ją ręcznie wcześniej).

    | Cecha                                                               | Opis                                                       |
    | ------------------------------------------------------------------- | ---------------------------------------------------------- |
    | **Zakres istnienia**                                                | Od momentu utworzenia do końca sesji.                      |
    | **Widoczność**                                                      | Tylko dla jednego użytkownika – inni jej nie widzą.        |
    | **Znika automatycznie**                                             | Po zamknięciu połączenia (albo po `DROP TEMPORARY TABLE`). |
    | **Nazwa może być taka sama jak zwykłej tabeli**                     | I MySQL będzie odwoływał się do tej tymczasowej.           |
    | **Można je modyfikować**                                            | Można `INSERT`, `UPDATE`, `DELETE` i tworzyć indeksy.      |
    | **Są przechowywane w pamięci lub tymczasowej przestrzeni dyskowej** | W zależności od rozmiaru i ustawień serwera.               |
    | **Można dodać indeksy i klucze**                                    | Tak jak do zwykłych tabel.                                 |
    | **Przydają się w przetwarzaniu pośrednim**                          | Agregaty, przeliczenia, dane etapowe w raportach itd.      |

    Kiedy MySQL usuwa tymczasową tabelę:
    ->  Gdy wywołasz: DROP TEMPORARY TABLE temp_name;
    ->  Gdy zamkniesz połączenie z bazą danych
    ->  Gdy zostanie zakończona sesja (np. po mysql_close())

    Dobre praktyki
    ->  Zawsze dodawaj TEMPORARY w CREATE TEMPORARY TABLE, by nie stworzyć przypadkiem zwykłej tabeli.
    ->  Używaj DROP TEMPORARY TABLE IF EXISTS – by nie wywaliło błędu przy usuwaniu.
    ->  Używaj sensownych nazw, np. z prefiksem temp_, żeby odróżnić od stałych tabel.

    Temporary table vs CTE

    ->  Zakres istnienia
        ->  CTE (WITH) istnieje tylko w ramach pojedynczego zapytania. Po jego wykonaniu CTE znika i nie
            można go ponownie wywołać, chyba że skopiujemy kod.
        ->  Tymczasowa tabela istnieje przez całą sesję, czyli aż do momentu jej jawnego usunięcia (DROP)
            lub zakończenia połączenia z bazą.

    ->  Mozliwosc modyfikacji danych
        ->  W CTE nie można bezpośrednio wykonywać operacji takich jak INSERT, UPDATE, czy DELETE – CTE to
            tylko „chwilowa” struktura do odczytu.
        ->  Tymczasowe tabele są w pełni funkcjonalne – można w nich modyfikować dane: dodawać, usuwać,
            aktualizować.

    ->  Indeksy i optymalizacja
        ->  CTE nie pozwala na tworzenie indeksów. Działa bardziej jak widok w locie – bez fizycznej struktury
            w bazie danych.
        ->  Tymczasowe tabele pozwalają na tworzenie indeksów (zarówno jawnych, jak i automatycznych – w
            zależności od silnika), co może znacząco poprawić wydajność w przypadku dużych danych i wielu
            operacji.

    ->  Widocznosc
        ->  CTE jest widoczne tylko w ramach pojedynczego zapytania lub bloku WITH – poza nim przestaje istnieć.
        ->  Tymczasowa tabela jest dostępna przez całą sesję i może być wykorzystywana w wielu zapytaniach,
            joinach, etapach przetwarzania itp.

    ->  Wydajność
        ->  CTE świetnie sprawdza się przy małych, jednorazowych obliczeniach, np. filtrach, warstwach logicznych
            czy rekurencji.
        ->  Tymczasowe tabele są lepszym wyborem przy dużych zbiorach danych, których przetwarzanie wymaga wielu
            etapów lub zapytań, np. w procesach ETL czy stagingu danych.

    ->  Wielokrotne użycie
        ->  CTE nie można ponownie użyć – za każdym razem trzeba napisać WITH i zdefiniować je od nowa.
        ->  Tymczasowa tabela może być wykorzystywana wielokrotnie w ramach jednej sesji, co sprawia, że jest
            wygodna przy analizach czy skomplikowanych pipeline’ach danych.

    ->  Obsługa rekurencji
        ->  CTE obsługuje rekurencję – można w niej budować np. hierarchie (drzewa, struktury organizacyjne itp.).
        ->  Tymczasowa tabela nie wspiera rekurencji wbudowanej, ale można ją ręcznie zaimplementować w kilku
            krokach, choć jest to mniej eleganckie i bardziej złożone.

    ->  Typowe zastosowania
        ->  CTE nadaje się do rekurencyjnych zapytań, agregacji, dzielenia logiki na warstwy, czy czytelnego
            rozbijania skomplikowanego zapytania na etapy.
        ->  Tymczasowe tabele są idealne w przypadku raportów, analizy danych etapami, przetwarzania danych
            w stagingu oraz w scenariuszach ETL, gdzie potrzebne są struktury wielokrotnego użytku.

    Czym jest staging?
    ->  Staging (etap przejściowy, buforowanie danych) to tymczasowa przestrzeń w bazie danych, w której gromadzi
        się surowe dane z różnych źródeł, zanim zostaną przekształcone i załadowane do docelowych tabel analitycznych,
        raportowych czy hurtowni danych.

    ->  Po co staging?
        ->  Oddziela import danych od ich przetwarzania – dane są najpierw „złapane” do stagingu.
        ->  Umożliwia walidację, czyszczenie, deduplikację i inne operacje przygotowujące dane.
        ->  Chroni główne tabele przed błędnymi, nieprzetworzonymi danymi.
        ->  Ułatwia debugowanie i audyt – można podejrzeć „stan surowy” przed obróbką.

    ->  Przyklad: Dane z API, Excela, innych baz trafiają najpierw do tabel stagingowych, np. stg_orders, zanim trafią
        do głównej tabeli orders.


    Czym jest ETL (Extract - Transform - Load)?

    ->  ETL to skrót od:
        ->  Extract (wydobycie) – pobieranie danych z różnych źródeł (np. baz danych, plików CSV, API).
        ->  Transform (transformacja) – przekształcanie danych: czyszczenie, normalizacja, łączenie, wyliczenia,
            zmiana formatu itp.
        ->  Load (ładowanie) – załadowanie przetworzonych danych do docelowej struktury – najczęściej do hurtowni
            danych lub finalnych tabel raportowych.

    W kontekście SQL, tymczasowe tabele są często wykorzystywane w fazach stagingu i ETL, ponieważ:
    ->  pozwalają etapowo przetwarzać dane,
    ->  mogą przechowywać tymczasowe wyniki transformacji,
    ->  umożliwiają kontrolę jakości danych przed finalnym załadowaniem.

    Jak omowione wyzej zagadnienia realizowane sa podczas pracy z temporary tables?
    ->  podczas Extract dane są ładowane do tymczasowych tabel stagingowych,
    ->  w Transform wykonujesz wiele zapytań (np. UPDATE, JOIN, DELETE) właśnie na tych tabelach,
    ->  po przygotowaniu dane są przenoszone (Load) do właściwych tabel raportowych, np. fact_sales, dim_customers.

    Ponizej zrealizujemy przykladowy scenariusz ETL.
    Zalozmy, ze otrzymujemy dane o zamowieniach klientow z systemu zewnetrznego (np. mamy jakies API albo plik CSV).
    Naszym celem jest:
    ->  Zaladowac dane do stagingu (tymczasowa tabela)
    ->  Wyczyscic i przygotowac dane (transform)
    ->  Zaladowac przygotowane dane do tabeli docelowej.
*/

-- Tworzymy tabele docelowa

create table if not exists orders(
    order_id int primary key,
    customer_name varchar(255),
    product_name varchar(255),
    quantity int,
    order_date date,
    status varchar(50)
);

-- Tymczasowa tabela - stanggingowa
-- Ta tabela bedzie przechowywac dane "surowe", zanim zostana przeksztalcone.
create temporary table temp_orders(
    raw_order_id varchar(20),
    raw_customer_name varchar(255),
    raw_product_name varchar(255),
    raw_quantity varchar(10),
    raw_order_date varchar(50),
    raw_status varchar(50)
);

drop temporary table temp_orders;
-- Dlaczego w tabeli tymczasowej wszystkie kolumny sa typu varchar?
-- Bo dane z zewnetrznych zrodel moga byc w niepewnym formacie -
-- lepiej najpierw je przyjac w formie tekstowej a potem dopiero przeksztalcac.

-- Teraz ladujemy dane czyli faza Extract
insert into temp_orders values
    ('001', ' John Doe ', 'Laptop', '2', '2025-07-20', 'completed'),
    ('002', 'JANE DOE', 'Smartphone', '1', '2025/07/19', 'Completed'),
    ('003', 'Mike Smith', 'Tablet', NULL, '19-07-2025', 'PENDING'),
    ('004', 'Alan Blake', 'Mouse', '1', '2025-07-59', 'PENDING');

select * from temp_orders;


-- Transformacja danych


-- Przekształcamy dane i kopiujemy je do temp_cleaned_orders
# insert into temp_cleaned_orders(order_id, customer_name, product_name, quantity, order_date, status)
# select
#     cast(raw_order_id as unsigned),
#     trim(upper(raw_customer_name)),
#     raw_product_name,
#     ifnull(cast(raw_quantity as unsigned), 0),
#     str_to_date(raw_order_date, '%Y-%m-%d'),
#     lower(raw_status)
# from temp_orders
# where raw_order_date regexp '^\\d{4}-\\d{2}-\\d{2}$'
#     and str_to_date(raw_order_date, '%Y-%m-%d') is not null;


-- Na poczatek przygotowujemy tabele valid_order_ids, ktora ma w sobie tylko id tych rekordow, ktore maja prawidlowa date

create temporary table valid_order_ids as
    select
        raw_order_id
from temp_orders
where
    raw_order_date REGEXP '^([0-9]{4})-(01|03|05|07|08|10|12)-(0[1-9]|[12][0-9]|3[01])$'
    OR raw_order_date REGEXP '^([0-9]{4})-(04|06|09|11)-(0[1-9]|[12][0-9]|30)$'
    OR raw_order_date REGEXP '^([0-9]{4})-02-(0[1-9]|1[0-9]|2[0-8])$'
    OR (
        raw_order_date REGEXP '^([0-9]{4})-02-29$' AND
        (
            MOD(SUBSTRING(raw_order_date, 1, 4), 4) = 0 AND
            (
                MOD(SUBSTRING(raw_order_date, 1, 4), 100) != 0 OR
                MOD(SUBSTRING(raw_order_date, 1, 4), 400) = 0
            )
        )
    );

drop temporary table valid_order_ids;

select * from valid_order_ids;

-- Tworzymy druga tymczasowa tabele, do ktorej wczytamy juz przeksztalcone dane
create temporary table temp_cleaned_orders (
       order_id int,
       customer_name varchar(255),
       product_name varchar(255),
       quantity int,
       order_date date,
       status varchar(50)
);

insert into temp_cleaned_orders(order_id, customer_name, product_name, quantity, order_date, status)
select
    cast(t.raw_order_id as unsigned),
    trim(upper(t.raw_customer_name)),
    t.raw_product_name,
    ifnull(cast(raw_quantity as unsigned), 0),
    str_to_date(t.raw_order_date, '%Y-%m-%d'),
    lower(t.raw_status)
from temp_orders t
join valid_order_ids v on t.raw_order_id = v.raw_order_id;


drop temporary table temp_cleaned_orders;

select * from temp_cleaned_orders;


-- Teraz kiedy masz przeksztalcone dane mozesz chciec je zaladowac do tabeli produkcyjnej (Load)
insert into orders (order_id, customer_name, product_name, quantity, order_date, status)
select * from temp_cleaned_orders;

-- Dalej pracujesz na danych produkcyjnych
select * from orders;




