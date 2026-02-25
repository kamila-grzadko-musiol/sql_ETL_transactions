use db;

# Dane Geoprzestrzenne (Spatial Data)
# MySQL wspiera dane przestrzenne zgodne ze standardem OGC (Open Geospatial Consortium). Pozwala to:
# -> przechowywać dane o położeniu (punkty, obszary),
# -> analizować położenie względne (czy punkt znajduje się w obszarze, jaka jest odległość itp.).
# POINT	            A single location in coordinate space
# LINESTRING	    A line consisting of a sequence of points
# POLYGON	        A closed area bounded by a sequence of points
# GEOMETRY	        General-purpose geometry container
# MULTIPOINT	    Collection of POINTs
# MULTILINESTRING	Collection of LINESTRINGs
# MULTIPOLYGON	    Collection of POLYGONs


-- Czym jest SRID (Spatial Reference System Identifier) to identyfikator układu odniesienia współrzędnych,
-- który mówi, jak interpretować współrzędne przestrzenne (np. punktu, linii, poligonu).
-- Kiedy masz punkt POINT(19.9450 50.0647) to:
-- bez SRID — MySQL nie wie, czy to długość/szerokość geograficzna (WGS 84),
-- z SRID = 4326 — oznacza, że punkt jest w systemie WGS 84 (czyli klasyczne GPS: długość i szerokość geograficzna w stopniach).
-- Typowe wartosci dla SRID
-- 4326 (WGS 84 – standard GPS (lat/lon w stopniach))
-- 3857 (Web Mercator – mapy internetowe (Google, Leaflet))
-- 0 (brak układu odniesienia (domyślny, "surowe dane"))
-- Funkcje przestrzenne (np. ST_Distance_Sphere) działają tylko, gdy geometrie mają ten sam SRID. Inaczej MySQL zwraca
-- błąd.

create table places (
    id int primary key auto_increment,
    name varchar(255) not null,
    location point srid 4326 not null,
    spatial index (location)
);


show create table places;

-- Jak sprawdzic SRID
select name, ST_SRID(location)
from places;

-- NAJPROSCIEJ jest zadbac o SRID od poczatku. Kiedy tworzysz kolumne location mozesz SRID ustawic.
-- W komercyjnych projektach SRID podaje się jawnie
-- Przy tworzeniu tabel: POINT SRID 4326
-- Przy tworzeniu danych: ST_GeomFromText('POINT(...)', 4326)
-- Ułatwia integrację z narzędziami GIS (np. QGIS, PostGIS, ArcGIS)
-- Unika się błędów typu "różne SRID-y w geometrii"

-- 1. Najprostszy sposób: bezpośrednio POINT(x, y)
-- Nie ustawia SRID
INSERT INTO places (name, location)
VALUES ('Park Centralny', POINT(19.9450, 50.0647));

-- Ustawia SRID
INSERT INTO places (name, location)
VALUES ('Park Centralny', ST_GeomFromText('POINT(19.9450 50.0647)', 4326));

-- 2. ST_GeomFromText z tekstem WKT (Well-Known Text)
-- Nie ustawia SRID
INSERT INTO places (name, location)
VALUES ('Zamek Królewski', ST_GeomFromText('POINT(21.0122 52.2470)'));

-- Ustawia SRID
INSERT INTO places (name, location)
VALUES ('Zamek Królewski', ST_GeomFromText('POINT(21.0122 52.2470)', 4326));

-- 3. ST_PointFromText – starsza funkcja, równoważna z ST_GeomFromText
-- Nie ustawia SRID
INSERT INTO places (name, location)
VALUES ('Jezioro Łabędzie', ST_PointFromText('POINT(18.5961 54.3512)'));

-- Ustawia SRID
INSERT INTO places (name, location)
VALUES ('Jezioro Łabędzie', ST_PointFromText('POINT(18.5961 54.3512)', 4326));

-- 4. ST_PointFromWKB – z binarnego formatu
-- Nie ustawia SRID
INSERT INTO places (name, location)
VALUES ('Góra Stołowa', ST_PointFromWKB(ST_AsBinary(POINT(16.3375, 50.4670))));

-- Ustawia SRID
INSERT INTO places (name, location)
VALUES (
           'Góra Stołowa',
           ST_PointFromWKB(ST_AsBinary(POINT(16.3375, 50.4670)), 4326)
       );

-- 5. ST_GeomFromGeoJSON – z JSON
-- Domyslnie ta opcja ustawia SRID na 4326, ale jak sprecyzujesz kolumne location ze ma pracowac z konkretny SRID ta
-- opcja nie dziala i musisz jawnie podawac srid
INSERT INTO places (name, location)
VALUES (
           'GeoJSON Punkt',
           ST_GeomFromGeoJSON('{
    "type": "Point",
    "coordinates": [19.9450, 50.0647],
  }')
       );

-- Ustawia SRID
INSERT INTO places (name, location)
VALUES (
           'GeoJSON Punkt',
           ST_GeomFromGeoJSON('{
    "type": "Point",
    "coordinates": [19.9450, 50.0647],
    "crs": {
      "type": "name",
      "properties": { "name": "EPSG:4326" }
    }
  }')
       );

select *
from places;

-- Dodatkowo pokazujemy ustawione SRID dla kazdego wiersza
select *, ST_SRID(location)
from places;


-- Znajdowanie lokalizacji w promieniu 10 km
select name from places where ST_Distance_Sphere(location, ST_GeomFromText('POINT(21.0122 52.2297)', 4326)) < 10000;

-- Liczenie odleglosci miedzy dwoma punktami
select ST_Distance_Sphere(
    (select location from places where id = 1),
    (select location from places where id = 2)
) / 1000 as distance_km;

-- Zwracanie najblizszego punktu
select name, ST_Distance_Sphere(
    location,
    ST_GeomFromText('POINT(19.9450 50.0647)', 4326)
) / 1000 as distance_km
from places
order by distance_km
limit 2;

-- Wyciaganie wspolrzednych z kolumny typu POINT
select
    name,
    ST_X(location) as longitude,
    ST_Y(location) as latitude
from places;

-- Zamiana point na inne typy
select ST_AsGeoJSON(location) from places;
select ST_AsText(location) from places;
# Zwraca dane w Well-Known Binary (WKB) – format binarny
select ST_AsBinary(location) from places;
# Dokładnie to samo co ST_AsBinary(...) – tylko inna nazwa
select ST_AsWKB(location) from places;
# Zwraca dane w Well-Known Text (WKT) – np. 'POINT(19.94 50.06)'
select ST_AsWKT(location) from places;

-- Dokladnie sprawdzanie punktow
select * from places where st_equals(location, ST_GeomFromText('POINT(19.9450 50.0647)', 4326));

-- Wyszukiwanie po przyblizonej szerokosci i dlugosci
select name
from places
where st_x(location) between 19.94 and 19.95 and st_y(location) between 50.06 and 50.07;

-- Aktualizacja lokalizacji
UPDATE places
SET location = ST_GeomFromText('POINT(19.9500 50.0650)', 4326)
WHERE name = 'Zamek Królewski';

-- Usuniecie wszystkich lokalizacji w promienu > 50 km
DELETE FROM places
WHERE ST_Distance_Sphere(location, ST_GeomFromText('POINT(19.9450 50.0647)', 4326)) > 50000;

select * from places;



# ---------------------------------------------------------------------------------------------------------------------
# LINESTRING
# LINESTRING to ciąg połączonych punktów. Idealny do reprezentowania:
# -> tras (np. linie autobusowe),
# -> ścieżek, dróg,
# -> rzek, kanałów.

create table routes (
    id int primary key auto_increment,
    name varchar(100) not null,
    path linestring srid 4326 not null,
    spatial index (path)
);

-- Wstawiamy dane - prosta trasa pomiedzy dwoma punktami
INSERT INTO routes (name, path)
VALUES (
    'Spacer po bulwarach',
     ST_GeomFromText('LINESTRING(19.9400 50.0610, 19.9450 50.0647, 19.9500 50.0670)', 4326)
);

INSERT INTO routes (name, path)
VALUES (
    'Spacer po bulwarach 2',
    ST_LineFromText('LINESTRING(19.94 50.06, 19.95 50.07)', 4326)
);


INSERT INTO routes (name, path)
VALUES (
           'Spacer po bulwarach 3',
           ST_GeomFromGeoJSON('{
                  "type": "LineString",
                  "coordinates": [
                    [19.94, 50.06],
                    [19.945, 50.065],
                    [19.95, 50.07]
                  ],
                  "crs": {
                    "type": "name",
                    "properties": { "name": "EPSG:4326" }
                  }
                }')
);

-- Pobierz pierwszy punkt z linii
select st_astext(st_startpoint(path)) as start from routes;

-- Pobierz 2. punkt z linii
select st_astext(st_pointn(path, 2)) as start from routes;

-- Pobierz ostatni punkt z linii
select st_astext(st_endpoint(path)) as end from routes;

-- Znalezienie tras w poblizu punktu
-- -- Wybierz trasy, które przecinają się z danym punktem
select name
from routes
where st_intersects(path, ST_GeomFromText('POINT(19.9450 50.0647)', 4326));

-- policz liczbe punktow w linestring
select name, st_numpoints(path) as points_num
from routes;

-- zwroc dlugosc trasy w km
select name, st_length(path) / 1000 as dist_km
from routes;

-- wyciagnij wspolrzedne wszystkich punktow z linestring
select
    r.name,
    st_astext(st_pointn(r.path, n.n)) as point
from routes r
join (
    select 1 as n union all select 2 union all select 3 union all select 4 union all select 5
) as n
where n.n <= st_numpoints(r.path)
order by name;

# ----------------------------------------------------------------------------------------------------------------------
# Czym jest unia?
# W SQL słowa kluczowe UNION i UNION ALL służą do łączenia wyników dwóch (lub więcej) zapytań SELECT w jeden zestaw
# wyników. Istnieje jednak istotna różnica między nimi:

# UNION
# Usuwa duplikaty – jeśli te same wiersze pojawią się w obu zapytaniach, zostaną pokazane tylko raz.
# Sortuje dane i filtruje unikalne wartości (co może być wolniejsze).

# UNION ALL
# Nie usuwa duplikatów – pokazuje wszystkie wiersze, nawet jeśli się powtarzają.
# Jest szybszy, bo nie musi sprawdzać unikalności.

select name from routes where id = 1
union
select name from routes where id = 2;

select name from routes where id = 1
union all
select name from routes where id = 2;

-- sprawdz, czy punkt lezy dokladnie na trasie
select name
from routes
where st_contains(path, ST_GeomFromText('POINT(19.9450 50.0647)', 4326));

# Jaka jest roznica pomiedzy st_contains oraz st_intersects?

# ST_Contains(geomA, geomB) sprawdza, czy geometria A całkowicie zawiera geometrię B.
# GeomB musi się mieścić w całości w GeomA.
# Jeśli choć część GeomB wychodzi poza GeomA → wynik: false.
# Zwraca TRUE tylko, jeśli punkt znajduje się w środku linii (na jej przebiegu).
# Jeśli punkt znajduje się na końcu linii (czyli na wierzchołku), może zwrócić FALSE
# — bo ST_Contains nie uznaje granicy jako "wnętrza".

# ST_Intersects(geomA, geomB)
# Sprawdza, czy geometrie A i B mają jakąkolwiek wspólną część.
# Wystarczy, że się dotykają (np. punkt na granicy poligonu).
# Albo częściowo nachodzą.
# Sprawdza, czy punkt dotyka linii – dowolnej jej części, także końców.
# Zwraca TRUE jeśli punkt leży na linii lub jej końcu.
