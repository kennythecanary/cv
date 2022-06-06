/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=47

Определить страны, которые потеряли в сражениях все свои корабли.
*/

WITH t (ship, country) AS (
  SELECT ship, country 
  FROM outcomes o JOIN classes c ON o.ship = c.class
  UNION
  SELECT name, country 
  FROM ships JOIN classes USING (class)
)
SELECT country
FROM (
  SELECT * FROM t JOIN outcomes USING (ship)
  WHERE result = 'sunk'
) q RIGHT JOIN t USING (ship, country)
GROUP BY country
HAVING SUM(IF(result IS NULL, 0,1)) = COUNT(IF(result IS NULL, 0,1));



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=104

Для каждого класса крейсеров, число орудий которого известно, пронумеровать (последовательно от единицы) все орудия.
Вывод: имя класса, номер орудия в формате 'bc-N'. 
*/

WITH RECURSIVE
t (class, num) AS (
  SELECT class, numguns FROM classes WHERE type = 'bc'
),
g AS (
  SELECT 1 num
  UNION
  SELECT g.num + 1 FROM g 
  WHERE g.num + 1 <= (SELECT MAX(num) FROM t)
)
SELECT class, CONCAT('bc-', g.num) num FROM t, g WHERE t.num >= g.num;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=117

По таблице Classes для каждой страны найти максимальное значение среди трех выражений:
numguns*5000, bore*3000, displacement.
Вывод в три столбца:
- страна;
- максимальное значение;
- слово `numguns` - если максимум достигается для numguns*5000, слово `bore` - если максимум достигается для bore*3000, слово `displacement` - если максимум достигается для displacement.
Замечание. Если максимум достигается для нескольких выражений, выводить каждое из них отдельной строкой.
*/

SELECT country, val max_val, name FROM (
  SELECT *, 
    DENSE_RANK() OVER(PARTITION BY country ORDER BY val DESC) r
  FROM (
    SELECT country, MAX(numguns)*5000 val, 'numguns' name
    FROM classes GROUP BY country
    UNION
    SELECT country, MAX(bore)*3000, 'bore' 
    FROM classes GROUP BY country
    UNION
    SELECT country, MAX(displacement), 'displacement'
    FROM classes GROUP BY country
  ) q
) q WHERE r = 1;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=118

Выборы Директора музея ПФАН проводятся только в високосный год, в первый вторник апреля после первого понедельника апреля.
Для каждой даты из таблицы Battles определить дату ближайших (после этой даты) выборов Директора музея ПФАН.
Вывод: сражение, дата сражения, дата выборов. Даты выводить в формате "yyyy-mm-dd".
*/

WITH RECURSIVE
r AS(
  SELECT YEAR(MIN(date)) dt FROM battles
  UNION 
  SELECT r.dt + 1 FROM r WHERE r.dt + 1 < (
    SELECT YEAR(MAX(date)) + 4 dt FROM battles)
),
t (dt) AS (
  SELECT STR_TO_DATE(CONCAT(dt, '-04-01'), '%Y-%m-%d')
  FROM r 
  WHERE dt % 4 = 0 AND (dt % 100 <> 0 OR dt % 400 = 0)
)
SELECT name, DATE(date) battle_dt, dt election_dt
FROM (
  SELECT *, ROW_NUMBER() OVER(PARTITION BY name ORDER BY dt) r
  FROM battles, (
    SELECT ADDDATE(ADDDATE(dt, MOD((9 - DAYOFWEEK(dt)), 7)), 1) dt 
    FROM t) q
  WHERE DATEDIFF(dt, date) > 0
) q
WHERE r = 1;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=121

Найдите названия всех тех кораблей из базы данных, о которых можно определенно сказать, что они были спущены на воду до 1941 г.
*/

-- Корабли, спущенные на воду до 1941 г.
SELECT name FROM ships WHERE launched < 1941 
UNION 
-- Корабли, участвующие в сражениях до 1941 г.
SELECT ship 
FROM outcomes o JOIN battles b ON o.battle = b.name
WHERE YEAR(date) < 1941
UNION
-- Головные корабли из таблицы Ships, год спуска которых не известен, но другие корабли из этого класса были спущены на воду до 1941 г.
SELECT name 
FROM ships 
WHERE name IN (
  SELECT class 
  FROM ships 
  WHERE launched < 1941
)
UNION
-- Головные корабли из таблицы Ships, год спуска которых не известен, но другие корабли из этого класса участвовали в сражениях до 1941 г.
SELECT name 
FROM ships 
WHERE name IN (
  SELECT class
  FROM outcomes o 
    JOIN battles b ON o.battle = b.name
    JOIN ships s ON s.name = o.ship
  WHERE YEAR(date) < 1941
)
UNION
-- Головные корабли из таблицы Outcomes, год спуска которых не известен, но другие корабли из этого класса были спущены на воду до 1941 г.
SELECT ship 
FROM outcomes
WHERE ship IN (
  SELECT class 
  FROM ships 
  WHERE launched < 1941
)
UNION
-- Головные корабли из таблицы Outcomes, год спуска которых не известен, но другие корабли из этого класса участвовали в сражениях до 1941 г.
SELECT ship 
FROM outcomes 
WHERE ship IN (
  SELECT class
  FROM outcomes o 
    JOIN battles b ON o.battle = b.name
    JOIN ships s ON s.name = o.ship
  WHERE YEAR(date) < 1941
);

