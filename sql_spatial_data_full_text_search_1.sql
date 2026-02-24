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
