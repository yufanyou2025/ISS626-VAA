# In-class Exercise 4

Separate from the unchanged Hands-on Exercise 4. The class script and photos guide the sequence: named-field join, GDPPC map, sf-to-sp conversion, CV/AICc bandwidth selection, GWSS, checked output join and local-mean map. Extensions compare five kernels and local correlations.

Open `In-class_Ex04.R` in the course RStudio project. Install the packages listed at its top, including GWmodel. Extract the supplied Hunan ZIP into this folder so `data/geospatial/Hunan.shp` and `data/aspatial/Hunan_2012.csv` exist, or set the R environment variable `COURSE_DATA_ZIP` to the archive path. The script records input checksums and validates 88 matched counties.

Run `source("In-class_Ex/In-class_Ex04/In-class_Ex04.R")` from the project root, or render `In-class_Ex/In-class_Ex04/In-class_Ex04.qmd` with Quarto. Rendering executes the script afresh; displayed excerpts and the complete script make all calculations inspectable. Raw teaching data remain local and are not redistributed.

Reference: https://github.com/tskam/ISSS626-AY2026-27Aug/blob/master/lesson/Lesson04/Lesson04-Spatial_Weights.qmd

Implementation and validation performed on 19 September 2026. Both bandwidth criteria return 22; all 88 local-statistics rows are finite and aligned before joining to polygons. Agricultural output is in RMB million; GDPPC is in RMB per person.
