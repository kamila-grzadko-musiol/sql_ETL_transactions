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