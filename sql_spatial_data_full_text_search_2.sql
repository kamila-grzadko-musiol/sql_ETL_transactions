# POLYGON — Reprezentacja obszaru (np. park, działka)
# POLYGON składa się z zamkniętej sekwencji punktów (LINEAR RING)
# Pierwszy i ostatni punkt muszą być identyczne
# Opcjonalnie: mogą zawierać otwory (np. jeziora w środku parku)

create table regions (
    id int primary key auto_increment,
    name varchar(100) not null,
    area polygon srid 4326 not null,
    spatial index (area)
);

insert into regions(name, area)
values ('Park',
    ST_GeomFromText('POLYGON((
        19.94 50.06,
        19.95 50.06,
        19.95 50.07,
        19.94 50.07,
        19.94 50.06
))', 4326));

insert into regions (name, area)
values (
   'Park 2',
   ST_GeomFromGeoJSON('{
          "type": "Polygon",
          "coordinates": [[
            [19.94, 50.06],
            [19.95, 50.06],
            [19.95, 50.07],
            [19.94, 50.07],
            [19.94, 50.06]
          ]],
          "crs": {
            "type": "name",
            "properties": { "name": "EPSG:4326" }
          }
        }')
);

-- sprawdzanie, czy punkt miesci sie w obszarze
select name
from regions
where st_contains(area, ST_GeomFromText('POINT(19.9450 50.0650)', 4326));

-- czy punkt tylko przecina polygon
SELECT name
FROM regions
WHERE ST_Intersects(area, ST_GeomFromText('POINT(19.9450 50.0650)', 4326));

-- wydobycie zewnetrznych granic (obwodu) regionu
select st_astext(st_exteriorring(area)) as boundary
from regions;

-- ilosc punktow granicznych
select st_numpoints(st_exteriorring(area)) as point_count
from regions;

# ----------------------------------------------------------------------------------------------------------------------
# GEOMETRY — typ ogólny
# GEOMETRY = kontener dowolnego typu geometrii (POINT, LINESTRING, POLYGON, MULTI*, itd.)
# Praktyczne w tabelach, gdzie mogą być różne rodzaje geometrii

create table geo_objects (
    id int primary key auto_increment,
    name varchar(100) not null,
    geom geometry srid 4326 not null,
    spatial index (geom)
);

-- Point
INSERT INTO geo_objects (name, geom)
VALUES ('My Point', ST_GeomFromText('POINT(19.94 50.06)', 4326));

-- LineString
INSERT INTO geo_objects (name, geom)
VALUES ('My Line', ST_GeomFromText('LINESTRING(19.94 50.06, 19.95 50.07)', 4326));

-- Polygon
INSERT INTO geo_objects (name, geom)
VALUES ('My Polygon', ST_GeomFromText('POLYGON((
    19.94 50.06,
    19.95 50.06,
    19.95 50.07,
    19.94 50.07,
    19.94 50.06
))', 4326));


select *
from geo_objects;

select
    name,
    st_geometrytype(geom) as type
from geo_objects;

# ----------------------------------------------------------------------------------------------------------------------
# MULTI* — dane wieloskładnikowe

# MULTIPOINT
create table multi_points (
    id int primary key auto_increment,
    name varchar(100) not null,
    points multipoint srid 4326 not null,
    spatial index (points)
);


INSERT INTO multi_points (name, points)
VALUES (
   'Cluster B',
   ST_GeomFromText('MULTIPOINT((19.94 50.06), (19.945 50.065), (29.95 50.07))', 4326)
);


-- Wycianij ile punktow masz w multipoint
select st_numgeometries(points) as num_pts
from multi_points;

-- Wycianij pojedynczy punkt
select st_astext(st_geometryn(points, 2)) from multi_points;

-- Sprawdz, czy ktorykolwiek z punktow w multipoints jest w konkretnym polygon
select name
from multi_points
where st_intersects(
    points,
    ST_GeomFromText('POLYGON((19.93 50.05, 19.93 50.08, 19.96 50.08, 19.96 50.05, 19.93 50.05))', 4326)
);

-- Sprawdz jakie punkty leza w tym obszarze
select
    name,
    n,
    ST_AsText(st_geometryn(points, n)) as point
from multi_points, (select 1 as n union all select 2 union all select 3) as nums
where st_contains(
    ST_GeomFromText('POLYGON((19.93 50.05, 19.93 50.08, 19.96 50.08, 19.96 50.05, 19.93 50.05))', 4326),
    ST_GeometryN(points, n)
);

-- MULTILINESTRING
create table multi_lines (
    id int primary key auto_increment,
    name varchar(100) not null,
    paths multilinestring srid 4326 not null,
    spatial index (paths)
);

INSERT INTO multi_lines (name, paths)
VALUES (
       'Double Route',
       ST_GeomFromText('MULTILINESTRING(
            (19.94 50.06, 19.95 50.07),
            (19.945 50.065, 19.955 50.075)
        )', 4326)
       );

-- Wyciaganie jednej linii
select st_astext(st_geometryn(paths, 1)) as line from multi_lines;

-- MULTIPOLYGON
create table multi_regions (
    id int primary key auto_increment,
    name varchar(100) not null,
    areas multipolygon srid 4326 not null,
    spatial index (areas)
);

INSERT INTO multi_regions (name, areas)
VALUES (
   'Two Parks',
   ST_GeomFromText('MULTIPOLYGON(
        ((19.94 50.06, 19.95 50.06, 19.95 50.07, 19.94 50.07, 19.94 50.06)),
        ((19.96 50.08, 19.97 50.08, 19.97 50.09, 19.96 50.09, 19.96 50.08))
        )', 4326)
);

-- Sprawdz, ile zawiera polygonow
select st_numgeometries(areas) from multi_regions;

-- Wydobadz pierwszy polygon
select st_astext(st_geometryn(areas, 1)) as area from multi_regions;

-- Sprawdz, czy punkt przecina MULTIPOLYGON
select name from multi_regions
where st_intersects(areas, ST_GeomFromText('POINT(19.945 50.065)', 4326));

-- ST_Union(geometry A, geometry B)
-- Łączy dwie geometrie w jedną. Działa z POLYGON, LINESTRING, MULTI*.
-- Dwa sąsiadujące prostokąty (wspólna krawędź)
SELECT ST_AsText(ST_Union(
    ST_GeomFromText('POLYGON((19.94 50.06, 19.95 50.06, 19.95 50.07, 19.94 50.07, 19.94 50.06))', 4326),
    ST_GeomFromText('POLYGON((19.95 50.06, 19.96 50.06, 19.96 50.07, 19.95 50.07, 19.95 50.06))', 4326)
));
-- Zastosowanie: łączenie obszarów (np. działek), tras, granic administracyjnych.

-- ST_Difference(geometry A, geometry B)
-- B obcina część A z prawej strony
SELECT ST_AsText(ST_Difference(
    ST_GeomFromText('POLYGON((19.94 50.06, 19.96 50.06, 19.96 50.07, 19.94 50.07, 19.94 50.06))', 4326),
    ST_GeomFromText('POLYGON((19.95 50.06, 19.97 50.06, 19.97 50.07, 19.95 50.07, 19.95 50.06))', 4326)
));
-- Zastosowanie: wycięcie strefy zakazanej, różnice między granicami, odjęcie np. zbiornika z parku.

-- ST_SymDifference(geometry A, geometry B)
-- Zwraca obszar, który należy do A lub B, ale nie do obu naraz
SELECT ST_AsText(ST_SymDifference(
    ST_GeomFromText('POLYGON((19.94 50.06, 19.96 50.06, 19.96 50.07, 19.94 50.07, 19.94 50.06))', 4326),
    ST_GeomFromText('POLYGON((19.95 50.06, 19.97 50.06, 19.97 50.07, 19.95 50.07, 19.95 50.06))', 4326)
));
-- Zastosowanie: porównania zasięgu dwóch stref, np. gdzie granice się różnią.

-- ST_Touches	Geometrie mają wspólną krawędź lub punkt, ale się nie nakładają
-- ST_Crosses	Linie przecinają się wewnątrz
-- ST_Overlaps	Geometrie częściowo się pokrywają

-- Przykład ST_Touches
SELECT ST_Touches(
       ST_GeomFromText('POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))'),
       ST_GeomFromText('POLYGON((1 0, 2 0, 2 1, 1 1, 1 0))')
);

-- Przykład ST_Overlaps
SELECT ST_Overlaps(
       ST_GeomFromText('POLYGON((0 0, 2 0, 2 2, 0 2, 0 0))'),
       ST_GeomFromText('POLYGON((1 1, 3 1, 3 3, 1 3, 1 1))')
);