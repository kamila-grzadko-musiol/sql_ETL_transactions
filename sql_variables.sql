/*
Zmienne użytkownika (@variable)
Zmienna użytkownika (ang. user-defined variable) to zmienna zdefiniowana przez użytkownika podczas
trwania sesji w MySQL. Jest tworzona "w locie", bez konieczności wcześniejszej deklaracji, poprzez
przypisanie wartości z użyciem prefiksu @.

Cechy charakterystyczne:
-> Obowiązuje tylko w danej sesji (czyli połączeniu z serwerem).
-> Może przechowywać dowolny typ danych (liczby, tekst, daty itd.).
-> Może być wykorzystywana w zapytaniach SELECT, UPDATE, INSERT, procedurach, itd.
-> Można ją przypisać za pomocą SET, SELECT, :=.
*/

SET @my_var = 100;
select @another_var := 'Hello';

-- Możesz takie zmienne używać w zapytaniach
SET @a = 10;
SET @b = 20;
select @a + @b as sum;


create table users(
    id int primary key auto_increment,
    username varchar(50)
);


select @counter := count(*) from users;

- Uwagi praktyczne:
-- -> Zmienna istnieje tak długo, jak trwa sesja. Po rozłączeniu z serwerem znika.
-- -> Nie trzeba jej deklarować wcześniej.
-- -> Jeśli jej wartość nie została jeszcze przypisana, jej domyślną wartością jest NULL.

-- Kiedy warto używać?
-- -> Gdy potrzebujesz tymczasowego przechowywania wartości w trakcie zapytań.
-- -> Do tworzenia obliczeń krok po kroku.
-- -> Do przetwarzania wyników z numeracją w zapytaniach.
-- -> Przy testowaniu lub debugowaniu zapytań SQL.

create table employees (
    id int primary key auto_increment,
    name varchar(100),
    department varchar(50),
    salary decimal(10, 2)
);

insert into employees (name, department, salary)
values
    ('Anna', 'HR', 4000),
    ('Bartek', 'HR', 4500),
    ('Celina', 'IT', 7000),
    ('Damian', 'IT', 6800),
    ('Ewa', 'IT', 7300),
    ('Filip', 'Sales', 3000),
    ('Grzegorz', 'Sales', 3200),
    ('Hania', 'Sales', 3500);


-- zapytanie z użyciem zmiennych użytkownika

-- @dept         numer bieżącej grupy działu (inkrementowany)
-- @prev_dept    nazwa poprzedniego działu (porównywanie zmian)
-- @rownum       numer wiersza w obrębie działu
-- @running      suma kumulacyjna wypłat
-- @prev_salary  poprzednia wypłata – do obliczenia różnicy

select
    @dept := if(@prev_dept = department, @dept, @dept + 1) as dept_group,
    @prev_dept := department as current_dept,
    @rownum := if(@prev_dept = department, @rownum + 1, 1) as dept_rownum,
    name,
    salary,
    @running := @running + salary as cumulative_salary,
    salary - @prev_salary as salary_diff,
    @prev_salary := salary as last_salary
from (
    select * from employees order by department, salary
) as sorted,
    (
        select @dept := 0,
               @prev_dept := '',
               @rownum := 0,
               @prev_salary := 0
    ) as vars;

select
-- Jeśli dział się nie zmienił – zachowujemy aktualny @dept.
-- Jeśli dział się zmienił – zwiększamy @dept (nowa grupa).
@dept := if(@prev_dept = department, @dept, @dept + 1) as dept_group,

-- Aktualizujemy @prev_dept, żeby użyć go w kolejnym wierszu.
-- To bardzo ważna linijka, przechowuje "stan" działu z bieżącego wiersza do następnego.
@prev_dept := department as current_dept,

-- Jeśli jesteśmy ciągle w tym samym dziale, zwiększamy numer wiersza.
-- Jeśli dział się zmienił, resetujemy numerację (1).
@rownum := if(@prev_dept = department, @rownum + 1, 1) as dept_rownum,

name,
salary,

-- Sumuje wynagrodzenia kumulacyjnie dla całej tabeli.
-- Na początku było 0, potem 0 + pierwsza pensja, potem + druga itd.
@running := @running + salary as cumulative_salary,
-- Obliczamy różnicę między bieżącą a poprzednią wypłatą.
salary - @prev_salary as salary_diff,
-- Ustawiamy @prev_salary na aktualne salary, zeby bylo gotowe na nastepny wiersz
@prev_salary := salary as last_salary
from (
    -- Tworzy posortowany widok pracowników wg działu i płacy rosnąco – potrzebne, by zapytanie
    -- przetwarzało wiersze w logicznej kolejności (działy grupami, od najniższej do najwyższej pensji).
    select * from employees order by department, salary
) as sorted,
-- To jest tzw. dummy select, który służy tylko do zainicjalizowania zmiennych
-- użytkownika przed wykonaniem głównego zapytania.
(
  select
    @dept := 0,
    @prev_dept := '',
    @rownum := 0,
    @running := 0,
    @prev_salary := 0
) as vars;

/*
Zmienne sesyjne (session variables)
Termin "session variables" jest szerszy i odnosi się do wszystkich zmiennych, których zakres ogranicza się do
bieżącej sesji połączenia z bazą danych. W ramach "session variables" wyróżniamy dwie główne kategorie:

-> Zmienne definiowane przez użytkownika (user-defined variables):
   I to są właśnie zmienne, które opisaliśmy wcześniej.
   Są one tworzone przez użytkownika za pomocą @ i ich zakres jest również ograniczony do bieżącej sesji.

-> Systemowe zmienne sesyjne (@@session.nazwa_zmiennej lub @@nazwa_zmiennej):
   -> Są to wbudowane zmienne konfiguracyjne MySQL, które wpływają na zachowanie serwera w kontekście bieżącej
      sesji.
   -> Przykłady to @@session.sql_mode, @@session.autocommit, @@session.character_set_results.
   -> Możesz je odczytywać za pomocą SELECT @@sql_mode; i często modyfikować za pomocą SET SESSION sql_mode = 'NOWA_WARTOŚĆ';.
   -> Wartości tych zmiennych są dziedziczone z globalnych zmiennych systemowych (@@global.nazwa_zmiennej)
      w momencie nawiązania połączenia.
*/

select @@session.sql_mode;

/*
Global Variables (Zmienne Globalne)
Zmienne globalne w MySQL są to zmienne konfiguracyjne, które wpływają na zachowanie całego serwera MySQL. Ich
wartości są wspólne dla wszystkich bieżących i przyszłych sesji połączeń z bazą danych.

-> Zakres: Działają na poziomie całego serwera. Zmiana wartości globalnej zmiennej wpływa na wszystkie sesje,
chyba że dana sesja nadpisze tę wartość swoją zmienną sesyjną.

-> Nazewnictwo: Zmienne globalne są identyfikowane przez prefiks @@global. lub po prostu @@.
   @@global.sql_mode
   @@global.max_connections

-> Odczyt: Możesz je odczytać za pomocą SELECT @@global.nazwa_zmiennej; lub
   SHOW GLOBAL VARIABLES LIKE 'nazwa_zmiennej';

-> Modyfikacja: Aby zmienić wartość globalnej zmiennej, używasz SET GLOBAL nazwa_zmiennej = wartość;. Wymaga
   to specjalnych uprawnień (zazwyczaj SUPER lub SYSTEM_VARIABLES_ADMIN).

-> Trwałość: Zmiany wprowadzone za pomocą SET GLOBAL są tymczasowe i tracone po restarcie serwera MySQL. Aby
   zmiany były trwałe po restarcie, musisz zmodyfikować plik konfiguracyjny MySQL (zazwyczaj my.cnf lub my.ini).
   W MySQL 8.0 wprowadzono również opcję SET PERSIST, która pozwala na trwałe zapisywanie zmian globalnych
   zmiennych bez edycji pliku konfiguracyjnego.

-> Brak "globalnych zmiennych zdefiniowanych przez użytkownika": MySQL nie pozwala na tworzenie "globalnych
   zmiennych zdefiniowanych przez użytkownika" (tj. czegoś w stylu SET GLOBAL @moja_zmienna = 'wartosc';).
   Zmienne z @ zawsze mają zakres sesyjny.

Przykłady zmiennych globalnych:
max_connections: Maksymalna liczba jednoczesnych połączeń z serwerem.
innodb_buffer_pool_size: Rozmiar bufora pamięci InnoDB.
log_bin: Czy log binarny jest włączony.
sql_mode: Tryb SQL, który wpływa na zachowanie serwera w zakresie zgodności z SQL.

Jak się mają do siebie (Global vs Session vs User-Defined Variables)
Wyobraź sobie serwer MySQL jako budynek z wieloma biurami (sesjami).

-> Global Variables (@@global.nazwa):
   To jak ogólne zasady i konfiguracje całego budynku.
   Na przykład, ile drzwi wejściowych może być otwartych (`max_connections`) albo jakie materiały budowlane
   są dozwolone (`sql_mode`). Te zasady dotyczą wszystkich w budynku, chyba że ktoś w swoim biurze (sesji)
   zdecyduje się je zmienić.

-> Session Variables (@@session.nazwa lub @@nazwa):
   To jak ustawienia w poszczególnych biurach.
   Kiedy nowa osoba wynajmuje biuro (nawiązuje nową sesję), jej biuro domyślnie przyjmuje ustawienia
   z „globalnych zasad budynku”. Ale ta osoba może, na przykład, zmienić kolor ścian w swoim biurze
   (`SET SESSION sql_mode = 'NOWA_WARTOŚĆ'`). Ta zmiana wpływa tylko na to jedno biuro i nie ma wpływu na
   inne biura ani na zasady całego budynku. Jeśli osoba opuści biuro, jej niestandardowe ustawienia znikają.

-> User-Defined Variables (@nazwa):
   To jak osobiste notatki lub karteczki, które trzymasz tylko na swoim biurku (w swojej sesji).
   Możesz na nich zapisać cokolwiek chcesz (`SET @licznik = 0;`), używać ich do swoich bieżących zadań,
   ale nikt inny w innym biurze ich nie widzi, a kiedy opuścisz biuro, te notatki są wyrzucane.


*/