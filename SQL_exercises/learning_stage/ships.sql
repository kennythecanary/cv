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



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=130

Историки решили составить отчет о битвах в два суперстолбца. Каждый суперстолбец состоит из трёх столбцов (номер битвы, название и дата).
Сначала в порядке возрастания номеров заполняется первый суперстолбец, потом - второй. Порядковый номер битве назначается согласно сортировке: дата, название.
С целью экономии бумаги, историки делят информацию из таблицы Battles поровну, занося в первый суперстолбец на одну битву больше при их нечетном количестве.
В таблицу с шестью колонками вывести результат работы историков, пустые места заполнить NULL-значениями. 
*/

WITH b(name, date, raw) AS(
  SELECT name, date, 
    ROW_NUMBER() OVER(ORDER BY date, name) raw
  FROM battles
)
SELECT q1.raw, q1.name, q1.date, q2.raw, q2.name, q2.date
FROM (
  SELECT *
  FROM b, (SELECT CEIL(COUNT(*)/2) thr FROM battles) q
  WHERE raw <= thr
) q1
LEFT JOIN (
  SELECT *, raw - thr con
  FROM b, (SELECT CEIL(COUNT(*)/2) thr FROM battles) q
  WHERE raw > thr
) q2 ON q1.raw = q2.con;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=132

Для каждой даты битвы (date1) взять дату следующей в хронологическом порядке битвы (date2), а если такой даты нет, то текущую дату.
Определить на дату date2 возраст человека, родившегося в дату date1 (число полных лет и полных месяцев).
Замечания:
1) считать, что полное число месяцев исполняется в дату дня рождения, или ранее, при условии, что более поздних дат в искомом месяце нет;
за полный год принимаются 12 полных месяцев; все битвы произошли в разные даты и до сегодняшнего дня.
2) даты представить без времени в формате "yyyy-mm-dd", возраст в формате "Y y., M m.", не выводить год или месяц если они равны 0,
для возраста менее 1 мес. выводить пустую строку.
Вывод: возраст, date1, date2. 
*/

SELECT 
  CASE 
    WHEN y > 0 AND m = 0 THEN CONCAT(y, ' y.') 
    WHEN y = 0 AND m > 0 THEN CONCAT(m, ' m.') 
    WHEN y > 0 AND m > 0 THEN CONCAT(y, ' y., ', m, ' m.') 
    ELSE '' END AS age,
  date1, date2
FROM (
  SELECT *, FLOOR(months / 12) y, months % 12 m
  FROM (
    SELECT *, TIMESTAMPDIFF(MONTH, date1, date2) + 
        IF(DAY(date1) > DAY(LAST_DAY(date2)), 1, 0) months
    FROM (
      SELECT date1, 
        IFNULL(LEAD(date1) OVER(ORDER BY date1), CURRENT_DATE()) date2
      FROM (
        SELECT DATE_FORMAT(date, '%Y-%m-%d') date1 FROM battles
      ) q
    ) q
  ) q
) q;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=136

Для каждого корабля из таблицы Ships, в имени которого есть символы, не являющиеся латинской буквой, вывести:
имя корабля, позиционный номер первого небуквенного символа в имени и сам символ.
*/

SELECT name, 
  INSTR(name, REGEXP_SUBSTR(name, '[^a-zA-Z]')) pos,
  REGEXP_SUBSTR(name, '[^a-zA-Z]') pat
FROM ships   
WHERE name RLIKE '[^a-zA-Z]';



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=139

Выведите страны, корабли которых не участвовали ни в одной битве.
*/

SELECT country
FROM (
  SELECT ship, country 
  FROM outcomes o JOIN classes c ON o.ship = c.class
  UNION
  SELECT name, country 
  FROM ships RIGHT JOIN classes USING (class)
) q
LEFT JOIN outcomes USING(ship)
GROUP BY country
HAVING COUNT(DISTINCT battle) = 0;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=140

Определить, сколько битв произошло в течение каждого десятилетия, начиная с даты первого сражения в базе данных и до даты последнего.
Вывод: десятилетие в формате "1940s", количество битв.
*/

WITH RECURSIVE
q(decade, date) AS(
  SELECT FLOOR(YEAR(date)/10)*10, date FROM battles
),
r AS(
  SELECT MIN(decade) decade FROM q
  UNION
  SELECT r.decade + 10 FROM r
  WHERE r.decade + 10 <= (SELECT MAX(decade) FROM q)
)
SELECT CONCAT(decade, 's') decade, 
  COUNT(DISTINCT date) n_battles
FROM q RIGHT JOIN r USING(decade)
GROUP BY decade;


