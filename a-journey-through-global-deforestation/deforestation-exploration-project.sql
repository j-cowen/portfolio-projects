-- Create forestation VIEW
CREATE VIEW forestation
AS
SELECT r.country_name,
        r.country_code,
        r.region,
        r.income_group,
        la.year,
        fa.forest_area_sqkm AS forest_area,
        la.total_area_sq_mi * 2.59 AS total_area, --convert sqmi to sqkm to match units for forest_area
        (fa.forest_area_sqkm / (total_area_sq_mi * 2.59))*100 AS percent_forest
FROM regions r
LEFT JOIN land_area la --Taiwan appears in regions table only, hence why a LEFT JOIN was used
ON r.country_code = la.country_code
LEFT JOIN forest_area fa
ON fa.country_code = la.country_code AND fa.year = la.year
ORDER BY 1,5;

-- PART 1: GLOBAL SITUATION

-- What was the total forest area (in sq km) of the world in 1990? Please keep in mind that you can use the country record denoted as “World" in the region table.

SELECT 
        country_name, 
        year, 
        forest_area
FROM forestation
WHERE year = 1990 AND country_name = 'World';

/*
Answer:
41,282,694.9 sq km
*/

-- b. What was the total forest area (in sq km) of the world in 2016? Please keep in mind that you can use the country record in the table is denoted as “World.”

SELECT 
        country_name, 
        year, 
        forest_area
FROM forestation
WHERE year = 2016 AND country_name = 'World';

/*
Answer:
39,958,245.9 sq km
*/

-- c. What was the change (in sq km) in the forest area of the world from 1990 to 2016?

SELECT country_name, 
        year, 
        forest_area,
        forest_area - LAG(forest_area) OVER (ORDER BY year) as LAG_difference
FROM forestation
WHERE (year = 1990 OR year = 2016) AND country_name = 'World';

/*
Answer:
-1,324,449 sq km
*/

-- d. What was the percent change in forest area of the world between 1990 and 2016?

SELECT t2.forest_area AS forest_area_1990,
        t1.forest_area AS forest_area_2016,
        ROUND(((t1.forest_area - t2.forest_area)/t2.forest_area)*100,2) AS percent_change
FROM forestation t1
INNER JOIN forestation t2
ON t1.country_name = t2.country_name
WHERE t1.year = 2016 AND t1.country_name = 'World' AND t2.year = 1990 AND t2.country_name = 'World';

/*
Answer:
-3.21 %
*/

-- e. If you compare the amount of forest area lost between 1990 and 2016, to which country's total area in 2016 is it closest to?

SELECT country_name,
        year,
        total_area
FROM forestation
WHERE year = 2016 AND total_area BETWEEN 1000000 AND 2000000
ORDER BY total_area DESC;

/*
Answer:
Peru
1,279,999.9891 sq km
*/

-- PART 2: REGIONAL OUTLOOK

-- Create a table that shows the Regions and their percent forest area (sum of forest area divided by sum of land area) in 1990 and 2016. (Note that 1 sq mi = 2.59 sq km).

CREATE VIEW regional_percent_forest 
AS
WITH t2 AS
    (SELECT region,
            year,
            (SUM(forest_area) / SUM(total_area))*100 AS region_percent_forest_1990
    FROM forestation
    WHERE year = 1990
    GROUP BY 1,2
    ORDER BY 1,2)
SELECT t1.region,
        t2.region_percent_forest_1990,
        (SUM(t1.forest_area) / SUM(t1.total_area))*100 AS region_percent_forest_2016
FROM forestation t1
INNER JOIN t2
ON t1.region = t2.region
WHERE t1.year = 2016
GROUP BY 1,2
ORDER BY 1,2;

--Based on the table you created...
--a. What was the percent forest of the entire world in 2016? 

SELECT ROUND(region_percent_forest_2016,2)
FROM regional_percent_forest
WHERE region = 'World';

/*
Answer:
31.38 %
*/

-- Which region had the HIGHEST percent forest in 2016?

SELECT region,
        region_percent_forest_2016
FROM regional_percent_forest
ORDER BY region_percent_forest_2016 DESC
LIMIT 1;

/*
Answer:
Latin America & Caribbean, 46.16 %
*/

-- Which region had the LOWEST, to 2 decimal places?

SELECT region,
        ROUND(region_percent_forest_2016::decimal,2)
FROM regional_percent_forest
ORDER BY region_percent_forest_2016
LIMIT 1;

/*
Answer:
Middle East & North Africa, 2.07 %
*/

-- b. What was the percent forest of the entire world in 1990? 

SELECT region_percent_forest_1990
FROM regional_percent_forest
WHERE region = 'World';

/*
Answer:
32.42 %
*/

-- Which region had the HIGHEST percent forest in 1990?

SELECT region,
        region_percent_forest_1990
FROM regional_percent_forest
ORDER BY region_percent_forest_1990 DESC
LIMIT 1;

/*
Answer:
Latin America & Caribbean, 51.03 %
*/

-- Which region had the LOWEST, to 2 decimal places?

SELECT region,
        ROUND(region_percent_forest_1990::decimal,2)
FROM regional_percent_forest
ORDER BY region_percent_forest_1990
LIMIT 1;

/*
Answer:
Middle East & North Africa, 1.78 %
*/

-- c. Based on the table you created, which regions of the world DECREASED in forest area from 1990 to 2016?

SELECT 
        *,
        region_percent_forest_2016 - region_percent_forest_1990 AS change_over_years
FROM regional_percent_forest
WHERE region_percent_forest_2016 - region_percent_forest_1990 <0 AND region != 'World'

/*
Answer:
Latin America & Caribbean (51.03 % to 46.16 %)
Sub-Saharan Africa (30.67 % to 28.79 %)
*/

-- PART 3:COUNTRY-LEVEL DETAIL

-- a. Which 5 countries saw the largest amount decrease in forest area from 1990 to 2016? What was the difference in forest area for each?

CREATE VIEW country_change_v3
AS
WITH t2 AS
        (SELECT country_name, 
                forest_area AS forest_area_1990,
                percent_forest AS percent_forest_1990
        FROM forestation
        WHERE year = 1990)
SELECT t1.country_name,
        t1.region,
        t2.forest_area_1990,
        t1.forest_area AS forest_area_2016,
        CAST(t1.forest_area - t2.forest_area_1990 AS int) AS change_in_forest_area,
        CASE
        WHEN t1.forest_area - t2.forest_area_1990 < 0
        THEN 'decrease'
        WHEN t1.forest_area - t2.forest_area_1990 > 0
        THEN 'increase'
        ELSE 'no change'
        END AS change,
        t2.percent_forest_1990,
        t1.percent_forest AS percent_forest_2016,
        ((t1.percent_forest - t2.percent_forest_1990) / t2.percent_forest_1990)*100 AS percent_change
FROM forestation t1
INNER JOIN t2
ON t2.country_name = t1.country_name
WHERE t1.year = 2016
ORDER BY 5;

SELECT
        country_name,
        change_in_forest_area
FROM country_change_v3
WHERE change = 'decrease' AND country_name <> 'World'
ORDER BY 2
LIMIT 5;

/*
Answer:
Brazil, Latin America & Caribbean, -541,510 sqkm
Indonesia, East Asia & Pacific, -282,193.98 sqkm
Myanmar, East Asia & Pacific, -107,234 sqkm
Nigeria, Sub-Saharan Africa, -106,506 sqkm
Tanzania, Sub-Saharan Africa, -102,320 sqkm
*/

-- b. Which 5 countries saw the largest percent decrease in forest area from 1990 to 2016? What was the percent change to 2 decimal places for each?

SELECT
        country_name,
        ROUND(percent_change::decimal,2)
FROM country_change_v3
WHERE change = 'decrease' AND country_name <> 'World'
ORDER BY 2
LIMIT 5;

/*
Answer:
Togo, Sub-Saharan Africa, -75.45 %
Nigeria, Sub-Saharan Africa, -61.80 %
Uganda, Sub-Saharan Africa, -59.27 %
Mauritania, Sub-Saharan Africa, -46.75 %
Honduras, Latin America & Caribbean, -45.03 %
*/

-- c. If countries were grouped by percent forestation in quartiles, which group had the most countries in it in 2016?

WITH t2 AS
(    SELECT country_name,
            percent_forest_2016,
            CASE
            WHEN percent_forest_2016 >= 0 AND percent_forest_2016 <= 25
            THEN 'Quartile 1'
            WHEN percent_forest_2016 > 25 AND percent_forest_2016 <= 50
            THEN 'Quartile 2'
            WHEN percent_forest_2016 > 50 AND percent_forest_2016 <= 75
            THEN 'Quartile 3'
            WHEN percent_forest_2016 > 75 AND percent_forest_2016 <= 100
            THEN 'Quartile 4'
            ELSE 'error'
            END AS quartile
    FROM country_change_v3
    WHERE forest_area_2016 is not null AND forest_area_2016 > 0 AND country_name != 'South Sudan' AND country_name != 'Sudan' AND country_name != 'World'
)
SELECT t2.quartile,
        COUNT(t2.quartile)
FROM country_change_v3 t1
INNER JOIN t2
ON t2.country_name = t1.country_name
GROUP BY 1
ORDER BY 1;

/*
Answer:
Quartile 1
*/

-- d. List all of the countries that were in the 4th quartile (percent forest > 75%) in 2016.

WITH t2 AS
(    SELECT country_name,
            percent_forest_2016,
            CASE
            WHEN percent_forest_2016 >= 0 AND percent_forest_2016 <= 25
            THEN 'Quartile 1'
            WHEN percent_forest_2016 > 25 AND percent_forest_2016 <= 50
            THEN 'Quartile 2'
            WHEN percent_forest_2016 > 50 AND percent_forest_2016 <= 75
            THEN 'Quartile 3'
            WHEN percent_forest_2016 > 75 AND percent_forest_2016 <= 100
            THEN 'Quartile 4'
            ELSE 'error'
            END AS quartile
    FROM country_change_v3
    WHERE forest_area_2016 is not null AND forest_area_2016 > 0 AND country_name != 'South Sudan' AND country_name != 'Sudan' AND country_name != 'World'
)
SELECT t2.country_name,
        t1.region,
        t2.percent_forest_2016,
        t2.quartile
FROM country_change_v3 t1
INNER JOIN t2
ON t2.country_name = t1.country_name
WHERE t2.quartile = 'Quartile 4'
ORDER BY 2 DESC;

/*
Answer:
Solomon Islands
Guyana
Suriname
American Samoa
Seychelles
Micronesia, Fed. Sts.
Palau
Gabon
Lao PDR
*/

-- e. How many countries had a percent forestation higher than the United States in 2016?

SELECT COUNT(country_name)
FROM forestation
WHERE year = 2016 AND percent_forest > (SELECT percent_forest
                                        FROM forestation
                                        WHERE year = 2016 AND country_name = 'United States')

/*
Answer:
94 countries
*/

-- SUCCESS STORIES (no prompts to answer this section)

SELECT *
FROM country_change_v3
WHERE change_in_forest_area is not null
ORDER BY 5 DESC;

China
527,229 sqkm increase

United States
79,200 sqkm increase

Iceland
