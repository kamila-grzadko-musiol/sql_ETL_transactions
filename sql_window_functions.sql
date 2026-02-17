/*
     Funkcje okienkowe w SQL to rodzaj funkcji agregujących, które działają na zbiorze wierszy (oknie)
     powiązanych z bieżącym wierszem, ale w przeciwieństwie do klasycznych funkcji agregujących (np.
     SUM, AVG, COUNT) nie agregują wyników do jednej wartości na grupę — zamiast tego zwracają wynik
     dla każdego wiersza osobno, z dostępem do danych z innych wierszy w jego oknie.

     Różnice: Window Functions vs. Group Functions (GROUP BY)

     Zwracana liczba wierszy
     Funkcje grupujące (GROUP BY): Jeden wiersz na grupę
     Funkcje okienkowe (Window Functions): Tyle samo wierszy, ile było

     Można używać z OVER
     Funkcje grupujące (GROUP BY): Nie
     Funkcje okienkowe (Window Functions): Tak

     Przykład użycia
     Funkcje grupujące (GROUP BY): SELECT dept, AVG(salary) FROM emp GROUP BY dept;
     Funkcje okienkowe (Window Functions): SELECT emp.*, AVG(salary) OVER(PARTITION BY dept) FROM emp;

     <funkcja_okienkowa>() OVER (
        [PARTITION BY <kolumny>]
        [ORDER BY <kolumny>]
        [ROWS BETWEEN ...]
    )

    Pojęcia:
    OVER(...) – mówi, że mamy do czynienia z funkcją okienkową.
    PARTITION BY – dzieli dane na grupy (partycje), ale nie agreguje jak GROUP BY; każda grupa jest
    analizowana osobno.
    ORDER BY – ustala kolejność wierszy w ramach każdej partycji.
    ROWS BETWEEN – definiuje "okno", np. poprzedni, bieżący i następny wiersz.
*/

create table employees (
    emp_id int primary key auto_increment,
    name varchar(50) not null,
    department varchar(50) not null,
    salary int
);

insert into employees (name, department, salary)
values
    ('Alice', 'IT', 5000),
    ('Bob', 'IT', 6000),
    ('Carol', 'HR', 4500),
    ('David', 'HR', 5500),
    ('Eve', 'IT', 7000),
    ('John', 'IT', 6000),
    ('Jim', 'HR', 8000),
    ('Jane', 'IT', 9000),
    ('Anna', 'HR', 2000);

select * from employees;

-- Grupowanie
select department, avg(salary) as avg_salary from employees group by department;

-- Funkcja okienkowa
select
    emp_id,
    name,
    department,
    salary,
    avg(salary)
        over(partition by department) as avg_salary_by_dept
from employees;

# ----------------------------------------------------------------------------------------------------------------------
# Funkcja okienkowe
# ----------------------------------------------------------------------------------------------------------------------

# ROW_NUMBER()
# Nadaje unikalny numer każdemu wierszowi w partycji.

-- Posortowaliśmy po salary malejąco, w kolumnie row_no mamy kolejno nadane numery wierszy w ramach
-- poszczególnych partycji
select
    emp_id,
    name,
    department,
    salary,
    row_number() over(partition by department order by salary desc) as row_no
from employees;

-- teraz wyciągniemy p 2 najlepiej zarabiające osoby w ramach departamentu
select *
from (select
    emp_id,
    name,
    department,
    salary,
    round(avg(salary) over(partition by department), 2)  as avg_salary_by_dept,
    row_number() over(partition by department order by salary desc) as row_no
from employees) as ranked
where row_no <= 2;

# RANK()
# Nadaje rangi, ale przy remisie pomija kolejne numery (skoki w numeracji).

select
    emp_id,
    name,
    department,
    salary,
    rank() over(partition by department order by salary) as ranked
from employees;

# DENSE_RANK()
# Jak RANK(), ale bez pomijania numerów przy remisie.

select
    emp_id,
    name,
    department,
    salary,
    dense_rank()  over(partition by department order by salary) as ranked
from employees;

# LEAD(column, offset, default)
# Zwraca wartość z kolejnego wiersza w oknie.



# LAG(column, offset, default)
# Zwraca wartość z poprzedniego wiersza.
select
    emp_id,
    name,
    department,
    salary,
    lag(salary)  over(partition by department order by salary) as previous_salary
from employees;

-- Zwraca pensję poprzedniego pracownika w dziale (według pensji rosnąco). Dla pierwszego
-- w każdym dziale zwróci NULL.

-- Kazdy pierwszy element z grupy ma przypisana domyslna wartosc 999
select
    emp_id,
    name,
    department,
    salary,
    lag(salary, 1, 999) over(partition by department order by salary) as previous_salary
from employees;

-- Wprowadzamy offset - interesuje nas wartosc z wiersza dwie pozycje wczesniej
select
    emp_id,
    name,
    department,
    salary,
    lag(salary, 2, 999) over(partition by department order by salary) as previous_salary
from employees;

-- Interesuje nas wartosc z pozycji pozniej
select
    emp_id,
    name,
    department,
    salary,
    lead(salary) over(partition by department order by salary) as next_salary
from employees;

-- Wartosc domyslna
select
    emp_id,
    name,
    department,
    salary,
    lead(salary, 1, 999) over(partition by department order by salary) as next_salary
from employees;

-- Interesuje nas wartosc z wiersza o 2 pozycje dalej
select
    emp_id,
    name,
    department,
    salary,
    lead(salary, 2, 999) over(partition by department order by salary) as next_salary
from employees;

# NTILE(n)
# Dzieli dane na n równych przedziałów.

select
    emp_id,
    name,
    department,
    salary,
    ntile(4) over(order by salary) as part
from employees;

# NTILE(n) dzieli dane po kolejności, nie po wartościach.
# Konkretnie:
# NTILE(n) OVER (ORDER BY ...) dzieli dane na n części na podstawie pozycji wiersza
# w posortowanym zbiorze, nie wartości kolumny.
# Wiersze są numerowane zgodnie z sortowaniem (ORDER BY) i przypisywane kolejno do grup
# od 1 do n.


# PERCENT_RANK()
# Oblicza względną pozycję każdego wiersza w zbiorze, jako procent.
# PERCENT_RANK = (RANK - 1) / (total_rows - 1)

select
    emp_id,
    name,
    department,
    salary,
    percent_rank() over(order by salary) as part
from employees;

# Otrzymane wartosci oznaczaja, jaki procent wierszy ma wartość mniejszą
# lub równą od bieżącej (bez siebie wliczając).


# CUME_DIST()
# Funkcja bardzo podobna do PERCENT_RANK, ale:
# Wlicza bieżący wiersz do pozycji procentowej.
# Wzór: (liczba wierszy z wartością ≤ aktualna wartość) / (liczba wszystkich wierszy)

select
    emp_id,
    name,
    department,
    salary,
    percent_rank() over(order by salary) as part_1,
    round(cume_dist() over(order by salary), 2) as part_2
from employees;

# Interpretacja wartości:
# 0.000 → najniższy wiersz w zbiorze (nikt nie ma niższej wartości)
# 0.250 → 25% danych znajduje się poniżej tego wiersza
# 0.500 → połowa danych ma wartość niższą lub równą (czyli mediana)
# 1.000 → najwyższy wiersz (wszystkie inne mają mniejsze)

# Co możesz z tym zrobić?
# Tworzyć klasyfikacje: np. pracownicy w górnych 10% (percent_rank >= 0.9)
# Dzielić dane na kwartyle, decyle, percentyle
# Porównywać pozycję pracownika względem całej populacji

# FIRST_VALUE() / LAST_VALUE()
# Zwraca pierwszą lub ostatnią wartość w oknie.
# last_value daje ostatnia wartosc ktora w danej chwili mamy na etapie wiersza w ktorym akurat jestesmy
# w trakcie przetwarzania okna

select
    emp_id,
    name,
    department,
    salary,
    first_value( salary) over(partition by department order by name) as first_salary,
    last_value( salary) over(partition by department order by name) as last_salary
from employees;

-- Mozesz uzywac dowolnej funkcji agregujacej

select
    emp_id,
    name,
    department,
    salary,
    sum(salary) over (
        partition by department
        order by name
        rows between unbounded preceding and current row )
        as sum_salary
from employees;

# rows between definiuje zakres (okno), czyli: dla każdego wiersza okresla, które inne
# wiersze są brane pod uwagę do SUM().
# ROWS — mówimy o rzeczywistych wierszach, nie wartościach (RANGE używa wartości).
# BETWEEN ... AND ... — określa granice okna
# UNBOUNDED PRECEDING — "od początku partycji" (czyli najwcześniejszy wiersz w danym dziale)
# CURRENT ROW — "do bieżącego wiersza w kolejności"

# Jak mozesz okreslac zakres wierszy?
# Składnia BETWEEN ... AND ... — dostępne opcje
# UNBOUNDED PRECEDING	Od początku partycji
# n PRECEDING	        n wierszy przed bieżącym
# CURRENT ROW	        Sam bieżący wiersz
# n FOLLOWING	        n wierszy po bieżącym
# UNBOUNDED FOLLOWING	Do końca partycji


select
    emp_id,
    name,
    department,
    salary,
    sum(salary) over (
        partition by department
        order by name
        rows between 1 preceding and 1 following )
        as sum_salary
from employees;

-- Wrocmy jeszcze do last_value

select
    emp_id,
    name,
    department,
    salary,
    first_value( salary) over(partition by department order by name) as first_salary,
    last_value( salary) over(partition by department order by name rows between unbounded preceding and unbounded following) as last_salary
from employees;

# Zamiast row mozesz zastosowac range

# ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
# → Weź dokładnie ten i jeden poprzedni wiersz (niezależnie od wartości).
#
# RANGE BETWEEN 100 PRECEDING AND CURRENT ROW
# → Weź wszystkie wiersze, których wartość ORDER BY mieści się w zakresie:
# ORDER BY_value - 100 do ORDER BY_value.

select salary,
    sum(salary) over (
    order by salary
        range between 100 preceding and current row
    ) as rolling_sum
from employees;

# Funkcja okienkowa ustawia dane rosnąco wg pensji (np. 2000, 2200, 2400, 2500, 2700, 3000, ...).
# RANGE BETWEEN 100 PRECEDING AND CURRENT ROW
# Dla każdego wiersza, weź wszystkie inne wiersze z tej samej partycji, których wartość salary mieści się w:
# [ salary-100, salary ]

# Aliasy dla window
# Pozwalaja zwiekszyc czytelnosc zapytania

# Aliasy dla window
# Pozwalaja zwiekszyc czytelnosc zapytania

select
    name,
    salary,
    row_number() over w as rn,
    rank() over w as rnk
from employees
window w as (partition by department order by salary);

# -> w to alias okna zdefiniowany na końcu zapytania.
# -> OVER w oznacza: "użyj tej samej definicji PARTITION BY department ORDER BY salary"
# -> Funkcje ROW_NUMBER() i RANK() korzystają z tej samej logiki podziału i sortowania.