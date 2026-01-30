use etl_transactions;

/*
    -------------------------------------------------------------------------------------------------------------------
    ETL
    -------------------------------------------------------------------------------------------------------------------

    ETL to proces przenoszenia i przetwarzania danych z różnych źródeł (np. systemów produkcyjnych, plików, API) do
    bazy docelowej, zwykle hurtowni danych (data warehouse), gdzie dane są gotowe do analizy i raportów.

    ETL = Extract – Transform – Load

    EXTRACT – Ekstrakcja danych
    Pobranie danych ze źródła. Może to być:
    -> baza danych (np. MySQL, PostgreSQL)
    -> plik CSV, Excel, XML
    -> API REST (np. dane pogodowe, giełdowe)
    -> system ERP, CRM
    -> dane przesyłane FTP

    TRANSFORM – Przetwarzanie danych
    Zamiana danych w taki sposób, aby były spójne, czyste, poprawne i gotowe do analizy.
    Rodzaj transformacji	        Przykład
    Czyszczenie danych	            Usunięcie NULL, błędnych formatów
    Normalizacja formatu	        'Kowalski jan' → 'Jan Kowalski'
    Łączenie danych	                Scalanie imienia i nazwiska, łączenie z inną tabelą
    Podział	                        Rozdzielenie adresu na miasto, ulicę
    Mapowanie wartości	            'PL' → „Polska”
    Agregacja	                    Suma sprzedaży, liczba zamówień
    Walidacja	                    Np. tylko poprawne numery PESEL
    Obliczenia	                    Np. wiek = dzisiaj - data_urodzenia

    LOAD – Załadowanie danych
    Załadowanie przetworzonych danych do docelowej bazy danych lub hurtowni (np. Redshift, BigQuery, PostgreSQL, MySQL),
    często do tabel faktów, wymiarów (w architekturze OLAP).
    3 podejscia do ladowania:
    Pełne (full)	Usuwa dane i ładuje wszystko od nowa
    Przyrostowe	    Tylko nowe / zmienione dane (np. przez updated_at)
    Hybrydowe	    Łączy powyższe (np. pełne raz w tygodniu, codziennie delta)

    ETL to ogólny model przetwarzania danych stosowany w systemach integracji danych, raportowania, hurtowni danych,
    systemach BI itp. Nie odnosi się do konkretnego języka czy technologii – ETL można zrealizować w MySQL, Pythonie,
    Talendzie, nawet w Excelu.

    Architektura ETL – Etapy krok po kroku
    1. Źródło danych – baza produkcyjna, API, CSV
    2. Staging area – tymczasowa tabela, bez zmian
    3. Cleaning / Transform – tabele pośrednie
    4. Final load – dane do tabel docelowych
    5. Logi i monitorowanie – zapis sukcesów / błędów

    Błędy i ryzyka w ETL
    Problem                         Skutek                          Rozwiazanie
    Brak walidacji danych	        Błędy w raportach	            Reguły czyszczenia w transformacji
    Zduplikowane dane	            Zawyżone sumy sprzedaży	        DISTINCT, klucz unikalny
    Brak logów błędów	            Brak kontroli jakości danych	Tabela logów, e-mail z błędami
    Przerwanie w połowie load	    Niepełne dane w hurtowni	    Transakcje lub MERGE zamiast INSERT
    Zmiany struktury źródła	        Awaria ETL	                    Wersjonowanie schematów


    -------------------------------------------------------------------------------------------------------------------
    TRANSAKCJE
    -------------------------------------------------------------------------------------------------------------------

    Transakcja to logiczna jednostka pracy z danymi – zestaw instrukcji SQL, które muszą zostać wykonane w całości
    albo wcale. Jeśli coś pójdzie nie tak w trakcie, możemy cofnąć cały zestaw operacji i baza wróci do stanu sprzed
    rozpoczęcia transakcji.

    4 podstawowe właściwości transakcji – zasada ACID:
    A	Atomicity	Wszystko albo nic (transakcja jest niepodzielna)
    C	Consistency	Dane po transakcji nadal spełniają ograniczenia (np. klucze, typy)
    I	Isolation	Transakcje są od siebie odseparowane (tymczasowo niezależne)
    D	Durability	Po COMMIT zmiany są trwałe — nawet przy awarii systemu

    Aby transakcje działały w MySQL, tabele muszą używać silnika InnoDB. Inne (np. MyISAM) tego nie wspierają.
    CREATE TABLE customers (
        id INT PRIMARY KEY,
        name VARCHAR(100)
    ) ENGINE=InnoDB;

    Podstawowa składnia transakcji:
    START TRANSACTION;

    -- kilka zapytań SQL
    -- ...

    COMMIT;   -- zapisuje zmiany
    ROLLBACK; -- cofa wszystkie zmiany od START TRANSACTION
*/

create table customers (
    customer_id int primary key auto_increment,
    name varchar(100) not null,
    email varchar(100) not null,
    phone_number varchar(100) not null
);

create table vehicles (
    vehicle_id int primary key auto_increment,
    customer_id int not null,
    brand varchar(50) not null,
    model varchar(50) not null,
    year year not null,
    foreign key (customer_id) references customers(customer_id) on delete cascade on update cascade
);

create table repairs (
    repair_id int primary key auto_increment,
    vehicle_id int not null,
    start_date date not null,
    end_date date not null,
    description text not null,
    foreign key (vehicle_id) references vehicles(vehicle_id) on delete restrict on update cascade
);


-- Dodajemy klientów
INSERT INTO customers (name, email, phone_number) VALUES
('Jan Kowalski', 'jan.kowalski@example.com', '555-1111'),
('Anna Nowak', 'anna.nowak@example.com', '555-2222'),
('Piotr Zieliński', 'piotr.zielinski@example.com', '555-3333');

-- Dodajemy pojazdy
INSERT INTO vehicles (customer_id, brand, model, year) VALUES
(1, 'Toyota', 'Corolla', 2015),
(1, 'Ford', 'Focus', 2012),
(2, 'BMW', '320i', 2018);

-- Dodajemy naprawy
INSERT INTO repairs (vehicle_id, start_date, end_date, description) VALUES
(1, '2024-01-10', '2024-01-15', 'Wymiana oleju'),
(2, '2024-02-05', '2024-02-06', 'Diagnostyka silnika'),
(3, '2024-03-01', '2024-03-07', 'Wymiana klocków hamulcowych');

# ----------------------------------------------------------------------------------------------------------------------
# Scenariusz 1
# Dodanie klienta i aktualizacja danych - wszystko naraz lub nic
# ----------------------------------------------------------------------------------------------------------------------

# Chcesz dodac nowego klienta. Od razu chcesz dokonac aktualizacji jego numeru telefonu. Jesli ktoraz z operacji
# sie nie uda to nie wykona sie nic.

start transaction;

insert into customers (name, email, phone_number)
values ('Adam Burak', 'adam@example.com', '111-333');
#
# # Kiedy wykonasz cala sekcje start transaction ... commit to ani insert ani update nie wykonaja sie
# # bo masz blad w nazwie tabeli w komendzie update.
update customer
set phone_number = '111-3333'
where email='adam@example.com';

commit;


# ----------------------------------------------------------------------------------------------------------------------
# Scenariusz 2
# Usunięcie klienta i jego powiązanych danych (np. pojazdów)
# ----------------------------------------------------------------------------------------------------------------------
# Chcesz usunąć klienta i wszystkie jego dane. Ale jeśli coś pójdzie nie tak – nie wolno zostawić bazy w połowie.

start transaction;

-- Najpierw usun naprawy (zalozmy, ze nie mozemy tego zrobic)
delete from repairs where repair_id = 3;
-- Teraz staram sie usunac vehicle ktory jest w relacji
delete from vehicles where vehicle_id = 2;
delete from repairs where repair_id = 2;

commit;

# ----------------------------------------------------------------------------------------------------------------------
# Scenariusz 3
# Jawne uzycie rollback
# ----------------------------------------------------------------------------------------------------------------------
# Wstawianie testowych danych


insert into customers (name, email, phone_number)
values
    ('Kamila Grządko-Musioł', 'kama@example.com', '111'),
    ('Ola Kostka', 'ola@example.com', '222');

select * from customers;

commit;
rollback;

# ----------------------------------------------------------------------------------------------------------------------
# Scenariusz 4
# Kolejnosc wywolywania start_transaction, rollback, commit
# ----------------------------------------------------------------------------------------------------------------------

start transaction;

insert into customers (name, email, phone_number)
values ('a', 'a@example.com', '111');

insert into customers (name, email, phone_number)
values ('c', 'c@example.com', '111');

rollback;
commit;
select * from customers;

# ----------------------------------------------------------------------------------------------------------------------
# Jak / kiedy dziala rollback?
# ----------------------------------------------------------------------------------------------------------------------
# Podstawowe zasady działania ROLLBACK w MySQL:
# Po START TRANSACTION, przed COMMIT -> ROLLBACK dziala
# Po COMMIT -> ROLLBACK nie dziala
# Bez START TRANSACTION (autocommit = ON) -> ROLLBACK nie dziala
# Jeśli autocommit = 0 i nie było COMMIT -> ROLLBACK dziala

select @@autocommit;
set autocommit = 0;
