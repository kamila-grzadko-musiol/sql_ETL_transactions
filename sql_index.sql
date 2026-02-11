/*
    Indeksy w MySQL to struktura danych, która przyspiesza wyszukiwanie danych w tabeli. Działa podobnie
    do indeksu w książce – zamiast przeszukiwać całą treść, można szybko znaleźć potrzebną informację.
    Domyślnie, MySQL musi przeszukać cały zbiór danych (tzw. full table scan), aby znaleźć pasujące
    rekordy. Indeks umożliwia przeszukiwanie tylko wybranych fragmentów danych, co znacząco przyspiesza
    zapytania SELECT, JOIN, WHERE, ORDER BY.

    Najczęściej stosowaną strukturą danych indeksów w MySQL (z silnikiem InnoDB) jest B-Tree.
    W niektórych przypadkach (np. indeksy pełnotekstowe i przestrzenne) stosuje się inne struktury,
    jak R-Tree lub FULLTEXT index engine.

    B-Tree (Balanced Tree) to samobalansujące się drzewo wyszukiwań, w którym dane są przechowywane
    w uporządkowany sposób, a operacje takie jak wyszukiwanie, wstawianie i usuwanie odbywają się
    w czasie logarytmicznym: O(log n).

    Struktura B-Tree:
    Każdy węzeł zawiera wiele kluczy (więcej niż dwa, w przeciwieństwie do drzew binarnych).
    Klucze są uporządkowane.
    Węzeł może mieć wiele dzieci (więcej niż dwa).
    Wszystkie liście znajdują się na tym samym poziomie.
    Klucze w lewym poddrzewie są mniejsze, a w prawym – większe niż dany klucz (jak w BST,
    ale wielokrotnie).

            [10 | 20]
           /    |    \
        [5]   [12]   [25, 30]
    Węzeł główny (root) zawiera klucze 10 i 20.
    Ma trzy dzieci:
    Pierwsze: zawiera klucze < 10 (czyli 5),
    Drugie: 10 <= klucz < 20 (czyli 12),
    Trzecie: >= 20 (czyli 25, 30).
    W MySQL (silnik InnoDB):
    -> PRIMARY KEY i unikalne indeksy są implementowane jako B-Tree (wariant B-Tree).
    -> Wszystkie dane tabeli są uporządkowane według klucza głównego.
    -> Liście B-Tree zawierają wszystkie dane wierszy (dla PRIMARY KEY) lub wskaźniki do
       danych (dla innych indeksów).
    -> Każdy węzeł pasuje do jednej strony (ang. page) o rozmiarze 16 KB.

    Przykladowe operacje na B-Tree:

    Wyszukiwanie
    -> Zaczynasz od korzenia.
    -> Porównujesz wartość z kluczami w węźle.
    -> Schodzisz odpowiednią gałęzią.
    -> Powtarzasz aż znajdziesz (lub nie) w liściu.

    Wstawianie
    -> Znajdź właściwy liść.
    -> Wstaw w odpowiednie miejsce.
    -> Jeśli węzeł się przepełni → podział węzła (split).
    -> Czasami trzeba też podzielić węzły nadrzędne → rekurencja w górę.

    Usuwanie
    -> Znajdź klucz i usuń.
    -> Jeśli po usunięciu węzeł ma za mało kluczy → scalanie lub pożyczanie od sąsiada.

    Dlaczego B-Tree w MySQL?
    -> Doskonale działa na dyskach (minimalizuje liczbę operacji I/O).
    -> Struktura dobrze radzi sobie z dużymi ilościami danych.
    -> Pozwala na efektywne zakresowe zapytania (BETWEEN, >, <, itd.).

    --------------------------------------------------------------------------------------------------------------------
    Rodzaje indeksow w MySQL.

    1.  PRIMARY KEY
        Główny indeks tabeli. Każda tabela może mieć tylko jeden PRIMARY KEY.
        Wymusza unikalność i brak NULL.
        Tworzy klastrowany indeks (clustered index).

        Clustered index (indeks klastrowany) to sposób przechowywania danych w tabeli, w którym:
        -> Dane wierszy tabeli są fizycznie posortowane według klucza indeksu.
        -> Każdy liść drzewa indeksu zawiera pełne dane wiersza.
        -> Tabela może mieć tylko jeden clustered index (bo danych nie można fizycznie posortować na dwa różne
           sposoby jednocześnie).

        W InnoDB:
        PRIMARY KEY = Clustered index
        Dane są uporządkowane fizycznie na dysku według wartości klucza głównego.
        Gdy tworzysz tabelę bez jawnego PRIMARY KEY, InnoDB wybierze:
        Pierwszy unikalny NOT NULL indeks jako clustered index, lub
        Doda ukryty 6-bajtowy row ID i użyje go jako clustered index.

        Masz tabelę users(id INT PRIMARY KEY, name VARCHAR(100)). Dane zostaną zapisane tak:
        B-Tree:
                  [5]
                /     \
          [1,2,3,4]   [6,7,8,9]
        Klucz id to PRIMARY KEY → clustered index.
        Liście tego drzewa zawierają pełne dane wierszy (czyli id + name).
        Jeśli szukasz id = 6, InnoDB przeszukuje B-Tree i trafia bezpośrednio do danych w liściu.

        Co z innymi indeksami (non-clustered)?
        Inne indeksy, np. INDEX(name), to secondary (non-clustered) indexes i działają trochę inaczej:
        Liście tych indeksów nie zawierają pełnych danych wiersza, tylko:
        -> wartość indeksu (name) oraz
        -> odwołanie do klucza głównego (PRIMARY KEY).
        Oznacza to, że zapytania po takich indeksach wymagają dodatkowego odczytu (tzw. "lookup" lub
        "bookmark lookup") – by odszukać dane w clustered indexie.

        Zalety clustered indexa:
        -> Szybkie wyszukiwanie po kluczu głównym.
        -> Szybkie zakresowe zapytania (BETWEEN, ORDER BY na kluczu głównym).
        -> Optymalne wykorzystanie pamięci dyskowej (bo dane i indeks są połączone).

    2.  UNIQUE INDEX
        -> Zapewnia unikalność wartości w kolumnie / kolumnach.
        -> Można mieć wiele UNIQUE indeksów w jednej tabeli.

    3.  REGULAR (NON-UNIQUE) INDEX
        -> Indeks przyspieszający wyszukiwanie, ale nie wymuszający unikalności.

    4.  COMPOSITE INDEX (wielokolumnowy)
        -> Indeks obejmujący kilka kolumn.
        CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date);
        -> Taki indeks działa dobrze dla zapytań, które używają kolumny customer_id, albo customer_id + order_date,
           ale nie działa dobrze tylko z order_date (tzw. leftmost prefix rule).

    5.  FULLTEXT INDEX
        -> Do wyszukiwania tekstu (np. w artykułach, opisach).
        -> Tylko dla kolumn typu TEXT, VARCHAR.

    6.  SPATIAL INDEX
        -> Używany w kolumnach typu GEOMETRY (np. dla danych geograficznych).
        -> Działa z silnikiem MyISAM lub InnoDB (od MySQL 5.7+).

    7.  FOREIGN KEY
        -> W silniku InnoDB, jeśli utworzysz FOREIGN KEY na kolumnie (lub zestawie kolumn), a nie istnieje na niej
        jeszcze indeks, MySQL automatycznie utworzy indeks typu BTREE na tej kolumnie.
        -> Jeśli indeks już istnieje (np. bo wcześniej ręcznie go utworzyłeś lub jest częścią innego indeksu),
        nowy nie zostanie dodany.

    --------------------------------------------------------------------------------------------------------------------
    ZALETY INDEKSÓW
    -> Szybsze zapytania SELECT
    -> Ograniczenie liczby przeszukiwanych rekordów.
    -> Szybsze sortowanie (ORDER BY)
    -> Szybsze filtrowanie (WHERE)
    -> Szybsze złączenia (JOIN)
    -> Wymuszanie unikalności (UNIQUE, PRIMARY KEY)

    WADY INDEKSÓW
    -> Zajmują dodatkowe miejsce na dysku. Czasem nawet większe niż sama tabela.
    -> Spowalniają operacje INSERT, UPDATE, DELETE. Bo każdy taki zapis musi aktualizować indeksy.
    -> Złożoność utrzymania. Źle zaprojektowane indeksy mogą bardziej zaszkodzić niż pomóc.
    -> Nie wszystkie zapytania skorzystają z indeksów. Np. zapytania z funkcjami (np. WHERE YEAR(date_column) = 2024)
       lub LIKE '%tekst%'.

    KIEDY UŻYWAĆ INDEKSÓW?

    UŻYWAJ:
    -> Gdy często wykonujesz zapytania z WHERE, JOIN, ORDER BY, GROUP BY.
    -> Gdy tabela ma wiele wierszy i czas odpowiedzi jest zbyt długi.
    -> Dla kolumn, które są często używane do wyszukiwania lub sortowania.

    NIE UŻYWAJ:
    -> Gdy tabela jest bardzo mała – pełne skanowanie może być szybsze.
    -> Dla kolumn, które są często aktualizowane, a nie służą do wyszukiwania.
    -> Gdy zapytania nie wykorzystują selektywnych warunków (np. boolean: is_active = 1 na 99% wierszy).

    DOBRE PRAKTYKI
    -> Nazewnictwo indeksów – np. idx_table_column1_column2.
    -> Indeksy selektywne – najlepiej, jeśli kolumna ma dużą różnorodność wartości.
    -> Nie nadużywaj indeksów – każda dodatkowa operacja INSERT / UPDATE / DELETE kosztuje.
    -> Analizuj z EXPLAIN i SHOW INDEX FROM.
    -> Stosuj kompozytowe indeksy zgodnie z kolejnością zapytań.
*/

create table users(
    user_id int primary key auto_increment,
    email varchar(255) not null,
    username varchar(250),
    create_at datetime
);

-- Unikalny indeks dla email
create unique index idx_users_email on users(email);

alter table users add column address varchar(50) unique;

-- Zwykły indeks na username (często używany do wyszukiwania)
create index idx_users_username on users(username);

-- Indeks dla create_at (np. do sortowania, filtrowania po dacie rejestracji)
create index idx_users_create_at on users(create_at);

create table orders (
    order_id int primary key auto_increment,
    user_id int not null,
    total_amount decimal(10,2),
    status varchar(50),
    order_date datetime,
    foreign key (user_id) references users(user_id) on delete cascade on update cascade
);
-- Indeks na user_id zostanie utworzony automatycznie przez FOREIGN KEY

-- Indeks kompozytowy dla raportow wg statusu i daty
create index idx_orders_status_order_date on orders(status, order_date);

-- Indeks na order_date do sortowania
create index idx_orders_order_date on orders(order_date);

create table products(
  product_id int primary key auto_increment,
  name varchar(255),
  category_id int,
  price decimal(10,2),
  create_at datetime
);

-- Indeksa na name (do szybkiego wyszukiwania po nazwie)
create index idx_products_name on products(name);

-- Kompozytowy indeks: do filtrowania po kategorii i sortowanie po cenie
create index idx_products_category_price on products(category_id, price);

-- Indeks na created_at (np. ostatnio dodane produkty)
create index idx_products_create_at on products(create_at);

create table articles (
    article_id int primary key auto_increment,
    title varchar(255),
    content text
);
-- Indeks fulltext na content
create fulltext index idx_article_content on articles(content);

-- Mozesz tez indeksowac kilka kolumn
create fulltext index idx_article_title_content on articles(title, content);

/*
    Oba powyzsze indeksy umożliwiają szybkie wyszukiwanie tekstu – w zależności od tego, czy przeszukujesz
    tylko content, czy title i content razem.

    SELECT * FROM articles
    WHERE MATCH(content) AGAINST('sztuczna inteligencja');
    -> Wyszukuje wszystkie wiersze, gdzie kolumna content zawiera słowo "sztuczna" lub "inteligencja".
    -> MySQL przeszukuje wcześniej utworzony FULLTEXT INDEX na content.
    -> Wyniki są rankowane według trafności (relevance score), domyślnie w trybie naturalnym (natural language mode).
    -> Nie szuka frazy dosłownie – liczy się obecność słów.

    SELECT * FROM articles
    WHERE MATCH(title, content) AGAINST('sztuczna inteligencja');

    -> Przeszukuje oba pola (title i content) jednocześnie.
    -> Zwraca wiersze, które mają dopasowanie w jednej lub obu kolumnach.
    -> Używa FULLTEXT INDEX na (title, content).
    -> Ranking wyników uwzględnia oba pola (np. jeśli słowo występuje w title, wynik może mieć wyższą wagę).

    FULLTEXT sprawdzi się, gdy:
    -> Duże ilości tekstu (artykuły, opisy, posty)
    -> Chcesz szukać słów/fraz w treści
    -> Potrzebujesz rankingu trafności

    Ograniczenia FULLTEXT:
    -> Małe kolumny z pojedynczymi słowami
    -> Używasz LIKE '%słowo%' zamiast MATCH
    -> Potrzebujesz dokładnego dopasowania znak w znak

    Ograniczenia:
    -> Tylko MATCH(...) AGAINST(...) aktywuje FULLTEXT – LIKE, = nie korzystają z indeksu.
    -> Domyślnie ignorowane są:
        -> słowa krótsze niż 3 znaki (innodb_ft_min_token_size),
        -> często występujące słowa (tzw. stop words).
    -> Tylko jeden FULLTEXT INDEX będzie użyty w zapytaniu.
    -> Nie działa na kolumnach typu JSON.
*/
/*
    Nie musisz jawnie wskazywać, że chcesz użyć indeksu w zapytaniu. Optymalizator zapytań (query optimizer)
    robi to automatycznie. Jak to działa:
    -> Gdy wykonujesz zapytanie (np. SELECT, UPDATE, DELETE), MySQL analizuje strukturę zapytania, dostępne
    indeksy i statystyki tabeli.
    -> Na tej podstawie decyduje, czy i który indeks będzie najefektywniejszy.
    -> Jeśli uzna, że pełny skan tabeli (full table scan) będzie szybszy (np. gdy warunek WHERE nie filtruje zbyt
    dużo danych), może zignorować indeks.

    Jeśli naprawdę chcesz, możesz użyć:

    -> USE INDEX – zasugeruj użycie konkretnego indeksu:
    SELECT * FROM users USE INDEX (idx_email) WHERE email = 'jan@example.com';

    -> FORCE INDEX – wymuś użycie danego indeksu (MySQL go wtedy prawie zawsze użyje):
    SELECT * FROM users FORCE INDEX (idx_email) WHERE email = 'jan@example.com';

    -> IGNORE INDEX – zignoruj konkretny indeks:
    SELECT * FROM users IGNORE INDEX (idx_email) WHERE email = 'jan@example.com';

    Nie nadużywaj FORCE INDEX – może to prowadzić do gorszej wydajności, jeśli dane się zmienią lub indeks
    przestanie być optymalny.
*/

create table locations (
    location_id int primary key auto_increment,
    name varchar(100),
    coordinates point not null,
    -- Indeks przestrzenny (SPATIAL) umożliwia szybkie zapytania geolokalizacyjne.
    spatial index (coordinates)
);

/*
    SPATIAL INDEX w MySQL służy do przyspieszania zapytań na kolumnach zawierających dane
    geometryczne, takich jak:
    POINT – współrzędne (x, y) → np. długość i szerokość geograficzna,
    LINESTRING, POLYGON, itd.
    Jest to indeks oparty na strukturze R-Tree, zoptymalizowanej pod zapytania przestrzenne.

    Stosuj go gdy:
    -> Przechowujesz dane geolokalizacyjne (np. współrzędne GPS)
    -> Chcesz robić zapytania typu „znajdź punkty w okolicy”
    -> Używasz funkcji przestrzennych MySQL (np. ST_Contains, MBRContains)

    SELECT * FROM locations
    WHERE MBRContains(
        ST_GeomFromText('POLYGON((10 10, 10 20, 20 20, 20 10, 10 10))'),
        coordinates
    );
    MBRContains oznacza "Minimum Bounding Rectangle Contains" – szybka wersja ST_Contains.

    SELECT *, ST_Distance_Sphere(coordinates, ST_GeomFromText('POINT(19.94 50.06)')) AS distance
    FROM locations
    ORDER BY distance
    LIMIT 5;
    To zapytanie oblicza odległość geograficzną (uwzględnia kulistość Ziemi), ale nie używa SPATIAL INDEX,
    bo ST_Distance_Sphere działa poza indeksem.
    Aby indeks działał, możesz najpierw zawęzić wyszukiwanie prostokątem (MBRContains) lub kołem.

    Wyobraź sobie aplikację lokalizacyjną – np. mapa kawiarni:
    -> Użytkownik podaje swoją lokalizację.
    -> System szuka kawiarni w promieniu 1 km.
    -> Najpierw zawężasz obszar MBRContains(...) z indeksem.
    -> Potem stosujesz dokładne ST_Distance_Sphere(...) dla top-N wyników.
*/

--  Sprawdzenie jakie indeksy istnieja
show index from orders;

/*
| Kolumna         | Znaczenie                                                                     |
| --------------- | ----------------------------------------------------------------------------- |
| `Table`         | Nazwa tabeli (czyli `orders`).                                                |
| `Non_unique`    | `0` jeśli indeks **unikalny**, `1` jeśli **nieunikalny**.                     |
| `Key_name`      | Nazwa indeksu (np. `PRIMARY`, `idx_customer_id`).                             |
| `Seq_in_index`  | Pozycja kolumny w indeksie (dla indeksów wielokolumnowych).                   |
| `Column_name`   | Nazwa kolumny, która jest częścią indeksu.                                    |
| `Collation`     | Jak sortowane są wartości (`A` = Ascending, `D` = Descending, `NULL` = brak). |
| `Cardinality`   | Szacunkowa liczba unikalnych wartości w kolumnie (dla optymalizatora).        |
| `Sub_part`      | Jeśli indeks jest na prefiksie kolumny (np. `VARCHAR(255)` z prefiksem).      |
| `Packed`        | Informacja o kompresji (zwykle `NULL`).                                       |
| `Null`          | Czy kolumna dopuszcza wartości `NULL`.                                        |
| `Index_type`    | Typ indeksu: `BTREE`, `FULLTEXT`, `SPATIAL`, `HASH`.                          |
| `Comment`       | Komentarz systemowy (czasem zawiera dodatkowe informacje).                    |
| `Index_comment` | Komentarz użytkownika (jeśli dodany przy tworzeniu indeksu).                  |
| `Visible`       | `YES`/`NO` – czy indeks jest widoczny dla optymalizatora (MySQL 8+).          |
| `Expression`    | Jeśli indeks bazuje na wyrażeniu (MySQL 8+), tu pojawi się wyrażenie.         |
*/

/*
EXPLAIN pokazuje plan wykonania zapytania – czyli w jakiej kolejności i w jaki sposób MySQL:
-> przeszukuje tabele,
-> używa indeksów (lub ich nie używa),
-> wykonuje złączenia,
-> filtruje i sortuje dane.

Dzięki temu możesz:
-> zoptymalizować zapytania,
-> zrozumieć, czy i jakie indeksy są wykorzystywane,
-> wykryć wolne zapytania i ich przyczyny.
*/

explain select * from products where name = 'Laptop';

/*
    Co dostaniesz w wyniku powyzszego zapytania:

    id
    Identyfikator zapytania lub podzapytania.
    Większa liczba = późniejsze wykonanie.

    select_type
    Rodzaj zapytania (SIMPLE, PRIMARY, SUBQUERY, DERIVED, UNION).

    table
    Nazwa tabeli (lub alias) aktualnie przetwarzanej.

    type – BARDZO WAŻNE!
    To typ dostępu – pokazuje, jak MySQL szuka danych. Od najlepszych do najgorszych:
    const	    1 wiersz – np. WHERE id = 5, super szybkie
    eq_ref	    Jedno dopasowanie, np. klucz obcy, JOIN po PK
    ref	        Szuka po indeksie z nieunikalnymi danymi
    range	    Zakres – np. WHERE date BETWEEN ...
    index	    Przeszukuje cały indeks
    ALL	        Pełne przeszukanie tabeli – NAJGORSZE

    possible_keys
    Indeksy, które mogłyby zostać użyte (wg MySQL).

    key
    Indeks, który został rzeczywiście użyty.

    key_len
    Długość użytej części indeksu (w bajtach).

    ref
    Wartość z porównania – np. const albo users.user_id.

    rows
    Liczba rzędów, które MySQL szacuje do przeszukania.

    filtered
    Procent wierszy, które przechodzą filtr (WHERE).

    Extra
    Dodatkowe informacje, np.:
    -> Using index – zapytanie może być obsłużone w całości z indeksu.
    -> Using where – dane są filtrowane po pobraniu.
    -> Using temporary – użycie tymczasowej tabeli (np. dla GROUP BY).
    -> Using filesort – sortowanie ręczne (nie przez indeks) – wolne!

    Kiedy używać EXPLAIN?
    -> Gdy optymalizujesz zapytanie.
    -> Gdy zapytanie działa wolno.
    -> Przed dodaniem indeksu – aby zobaczyć, czy zapytanie go wykorzystuje.
    -> Po dodaniu indeksu – aby potwierdzić, że działa.
*/

