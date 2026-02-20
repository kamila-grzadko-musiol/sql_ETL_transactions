create table students(
    student_id int primary key auto_increment,
    student_name varchar(100),
    enrollment_year int
);

create table exams (
    exam_id int primary key auto_increment,
    student_id int,
    subject varchar(50),
    score int,
    exam_date date,
    foreign key (student_id) references students(student_id) on delete cascade on update cascade
);

-- Studenci
INSERT INTO students (student_id, student_name, enrollment_year)
VALUES
     (1, 'Alice', 2021),
     (2, 'Bob', 2021),
     (3, 'Charlie', 2022),
     (4, 'Diana', 2022),
     (5, 'Eve', 2023);

-- Egzaminy
INSERT INTO exams (exam_id, student_id, subject, score, exam_date)
VALUES
    (1, 1, 'Math', 80, '2023-01-10'),
    (2, 1, 'Physics', 75, '2023-02-15'),
    (3, 2, 'Math', 90, '2023-01-12'),
    (4, 2, 'Physics', 90, '2023-02-17'),
    (5, 3, 'Math', 70, '2023-03-01'),
    (6, 3, 'Physics', 50, '2023-03-10'),
    (7, 4, 'Math', 60, '2023-03-05'),
    (8, 4, 'Physics', 65, '2023-03-15'),
    (9, 5, 'Math', 95, '2023-04-01'),
    (10, 5, 'Physics', 85, '2023-04-10');

# 1. Średnia punktacja z danego przedmiotu
#    student_name, score, subject, średni wynik

select
    s.student_name,
    e.subject,
    e.score as student_score,
    avg(e.score) over (partition by e.subject) as avg_score_by_subject
from exams e
join students s on s.student_id = e.student_id;

# 2. Numeracja wyników w przedmiocie - najpierw posortuj po wyniku malejaco, chce zobaczyc
#    student name, nazwe przedmiotu, wynik kazdego studenta i kolejny przydzielony numer

select
    s.student_name,
    e.subject,
    e.score as student_score,
    row_number() over (partition by e.subject order by e.score desc) as row_no
from exams e
join students s on s.student_id = e.student_id;

# 3. Ranking punktacji w przedmiocie, ale tylko dla egzaminów z wynikiem powyżej 60.
#    Dla każdego egzaminu z danego przedmiotu, jeśli wynik był powyżej 60, nadaj
#    studentowi miejsce w rankingu (RANK) wg punktów.

select
    s.student_name,
    e.subject,
    e.score,
    dense_rank() over (partition by e.subject order by e.score desc) as row_no
from exams e
join students s on s.student_id = e.student_id
where e.score > 60;

# 4. Dla każdego studenta i przedmiotu, pokaż ile punktów zdobył oraz ile punktów zdobył
#    w poprzednim podejściu. Oblicz różnicę.
select
    s.student_name,
    e.subject,
    e.exam_date,
    e.score,
    lag(e.score, 1, 0) over (partition by e.student_id, e.subject order by e.exam_date) as prev_score,
    e.score - lag(e.score, 1, 0) over (partition by e.student_id, e.subject order by e.exam_date) as score_diff
from exams e
join students s on s.student_id = e.student_id;


select
    s.student_name,
    e.subject,
    e.exam_date,
    e.score,
    lag(e.score, 1, 0) over w as previous_score,
    e.score - lag(e.score, 1, 0) over w as scores_difference
from exams e
join students s on s.student_id = e.student_id
window w as (partition by e.student_id, e.subject order by e.exam_date);

# 5. Dla każdego przedmiotu, oblicz średnią punktację z danego egzaminu oraz jednego wcześniejszego.

select
    s.student_name,
    e.subject,
    e.exam_date,
    e.score,
    round(avg(e.score)
              over (
                  partition by e.subject
                  order by e.exam_date
                  rows between 1 preceding and current row ), 2)
        as avg_last_two_scores
from exams e
join students s on s.student_id = e.student_id;

# Moglbys zinterpretowac to w ten sposób, ze mamy wyniki egzaminow, ktore odbyly się w roznych
# terminach. Wiec zrobmy, ze interesuje nas srednia ze srednich z dwoch terminow obok siebie

select
    sub.subject,
    sub.exam_date,
    sub.avg_score,
    round(
        avg(sub.avg_score) over (
            partition by sub.subject
            order by sub.exam_date
            rows between 1 preceding and current row)
        , 2)
from (
    select
    subject,
    exam_date,
    round(avg(score), 2) as avg_score
from exams
group by subject, exam_date
) as sub;

# 6. Dla każdego studenta pokaż datę obecnego egzaminu i następnego, niezależnie od przedmiotu.

select
    s.student_name,
    e.exam_date as current_exam,
    lead(e.exam_date) over (partition by e.student_id order by e.exam_date) as next_exam
from exams e
join students s on s.student_id = e.student_id;

# 7. Dla każdego studenta policz, jak długo czekał na kolejny egzamin (różnica dni)

select
    s.student_name,
    e.exam_date as current_exam,
    lead(e.exam_date) over (partition by e.student_id order by e.exam_date) as next_exam,
    datediff(
        lead(e.exam_date) over (partition by e.student_id order by e.exam_date), e.exam_date
    ) as days_between
from exams e
join students s on s.student_id = e.student_id;

select
    s.student_name,
    e.exam_date as current_exam,
    lead(e.exam_date) over w as next_exam,
    datediff(
            lead(e.exam_date) over w,
            e.exam_date
    ) as days_between
from exams e
join students s on s.student_id = e.student_id
window w as (partition by e.student_id order by e.exam_date);

# 8. Dla każdego przedmiotu oblicz różnicę między średnią punktacją bieżącego terminu a poprzedniego
#    Wyświetl datę, przedmiot, średnią punktację danego terminu oraz różnicę względem średniej
#    z poprzedniego terminu.

select subject,
       exam_date,
       avg_score,
       abs(avg_score - lag(avg_score) over (
           partition by subject order by exam_date
           )) as avg_abs_diff
from (
    select
    subject,
    exam_date,
    round(avg(score), 2) as avg_score
from exams e
group by subject, exam_date
) as avg_scores_by_subject;


# 9. Czy student poprawił wynik w kolejnym egzaminie (tak / nie)?
#    Wyświetl dane: student, przedmiot, aktualny wynik, poprzedni wynik oraz odpowiedź: 'yes' jeśli
#    wynik się poprawił, 'no' w przeciwnym razie.