/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=102

Определить имена разных пассажиров, которые летали
только между двумя городами (туда и/или обратно). 
*/

SELECT name 
FROM (
  SELECT trip_no, town_from town, time_out time FROM Trip
  UNION
  SELECT trip_no, town_to, time_in FROM Trip
) t 
JOIN Pass_in_trip USING (trip_no) JOIN Passenger USING (id_psg)
GROUP BY id_psg
HAVING COUNT(DISTINCT town) = 2;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=103

Выбрать три наименьших и три наибольших номера рейса. Вывести их в шести столбцах одной строки, расположив в порядке от наименьшего к наибольшему.
Замечание: считать, что таблица Trip содержит не менее шести строк. 
*/

WITH 
q (trip_no, f, b, c) AS (
  SELECT trip_no, 
    ROW_NUMBER() OVER(ORDER BY trip_no),
    ROW_NUMBER() OVER(ORDER BY trip_no DESC),
    1
  FROM trip
)
SELECT t1.trip_no min1, t2.trip_no min2, t3.trip_no min3,
  t4.trip_no max1, t5.trip_no max2, t6.trip_no max3
FROM
(SELECT trip_no, c FROM q WHERE f=1) t1 JOIN
(SELECT trip_no, c FROM q WHERE f=2) t2 USING(c) JOIN
(SELECT trip_no, c FROM q WHERE f=3) t3 USING(c) JOIN
(SELECT trip_no, c FROM q WHERE b=3) t4 USING(c) JOIN
(SELECT trip_no, c FROM q WHERE b=2) t5 USING(c) JOIN
(SELECT trip_no, c FROM q WHERE b=1) t6 USING(c);



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=107

Для пятого по счету пассажира из числа вылетевших из Ростова в апреле 2003 года определить компанию, номер рейса и дату вылета.
Замечание. Считать, что два рейса одновременно вылететь из Ростова не могут. 
*/

SELECT name, trip_no, date
FROM (
  SELECT *, ROW_NUMBER() OVER(ORDER BY date, time_out) num
  FROM trip 
    JOIN pass_in_trip USING(trip_no) 
    JOIN company USING(id_comp)
  WHERE town_from = 'Rostov'
    AND YEAR(date) = 2003 AND MONTH(date) = 4
) q 
WHERE num = 5;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=110

Определить имена разных пассажиров, когда-либо летевших рейсом, который вылетел в субботу, а приземлился в воскресенье. 
*/

SELECT name FROM passenger JOIN (
  SELECT DISTINCT id_psg
  FROM trip 
    JOIN pass_in_trip USING (trip_no)
    JOIN passenger USING (id_psg)
  WHERE DAYNAME(date) = 'Saturday'
    AND time_in < time_out
) q USING (id_psg);



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=114

Определить имена разных пассажиров, которым чаще других доводилось лететь на одном и том же месте. Вывод: имя и количество полетов на одном и том же месте. 
*/

WITH t (id_psg, fq) AS (
  SELECT DISTINCT id_psg, COUNT(place) OVER(PARTITION BY id_psg, place) 
  FROM trip 
    JOIN pass_in_trip USING (trip_no)
) 
SELECT name, fq FROM t JOIN passenger USING (id_psg)
WHERE fq = (SELECT MAX(fq) FROM t);



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=120

Для каждой авиакомпании, самолеты которой перевезли хотя бы одного пассажира, вычислить с точностью до двух десятичных знаков средние величины времени нахождения самолетов в воздухе (в минутах). Также рассчитать указанные характеристики по всем летавшим самолетам (использовать слово 'TOTAL').
Вывод: компания, среднее арифметическое, среднее геометрическое, среднее квадратичное, среднее гармоническое.

Для справки:
среднее арифметическое = (x1 + x2 + ... + xN)/N
среднее геометрическое = (x1 * x2 * ... * xN)^(1/N)
среднее квадратичное = sqrt((x1^2 + x2^2 + ... + xN^2)/N)
среднее гармоническое = N/(1/x1 + 1/x2 + ... + 1/xN)
*/

SELECT 
  CASE
    WHEN id_comp IS NULL THEN 'TOTAL'
    ELSE name
  END AS name,
  avg, geom, rms, harm
FROM (
  SELECT 
    id_comp,
    ROUND(AVG(tmin), 2) avg,
    ROUND(POW(EXP(SUM(LN(tmin))), 1/COUNT(tmin)), 2) geom,
    ROUND(SQRT(AVG(POW(tmin, 2))), 2) rms,
    ROUND(COUNT(tmin)/SUM(1/tmin), 2) harm
  FROM (
    SELECT id_comp, IF(tmin > 0, tmin, 1440 + tmin) tmin
    FROM (
      SELECT DISTINCT id_comp, trip_no, date,
        TIMESTAMPDIFF(MINUTE, time_out, time_in) tmin
      FROM pass_in_trip JOIN trip USING(trip_no)
    ) q
  ) q
  GROUP BY id_comp WITH ROLLUP
) q 
LEFT JOIN company USING(id_comp);



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=122

Считая, что первый пункт вылета является местом жительства, найти пассажиров, которые находятся вне дома. Вывод: имя пассажира, город проживания.
*/

WITH q(name, id_psg, town_from, town_to, trip_r, trip_q) 
AS(
  SELECT name, id_psg, town_from, town_to,
    RANK() OVER(PARTITION BY id_psg ORDER BY date, time_out), 
    COUNT(trip_no) OVER(PARTITION BY id_psg) 
  FROM pass_in_trip 
    JOIN trip USING(trip_no)
    JOIN passenger USING(id_psg)
)
SELECT name, town_from home 
FROM q JOIN (
  SELECT id_psg, town_to curr_loc FROM q WHERE trip_r = trip_q
) q1 USING (id_psg)
WHERE trip_r = 1 AND town_from <> curr_loc
ORDER BY 1;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=124

Среди пассажиров, которые пользовались услугами не менее двух авиакомпаний, найти тех, кто совершил одинаковое количество полётов самолетами каждой из этих авиакомпаний. Вывести имена таких пассажиров. 
*/

SELECT name
FROM (
  SELECT id_psg, id_comp, 
    DENSE_RANK() OVER(PARTITION BY id_psg ORDER BY id_comp) rnk,
    COUNT(trip_no) OVER(PARTITION BY id_psg, id_comp) cnt
  FROM pass_in_trip JOIN trip USING(trip_no)
) q
JOIN passenger USING(id_psg)
GROUP BY id_psg
HAVING MAX(rnk) > 1
   AND AVG(cnt) = MAX(cnt);



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=126

Для последовательности пассажиров, упорядоченных по id_psg, определить того,
кто совершил наибольшее число полетов, а также тех, кто находится в последовательности непосредственно перед и после него.
Для первого пассажира в последовательности предыдущим будет последний, а для последнего пассажира последующим будет первый.
Для каждого пассажира, отвечающего условию, вывести: имя, имя предыдущего пассажира, имя следующего пассажира. 
*/

WITH 
q (id_psg, ctr) AS(
  SELECT id_psg, COUNT(place) FROM pass_in_trip GROUP BY id_psg
),
p (id_psg, name, prev, next) AS(
  SELECT *,
    IFNULL(LAG(name) OVER(ORDER BY id_psg),
      FIRST_VALUE(name) OVER(ORDER BY id_psg DESC ROWS UNBOUNDED PRECEDING)
    ),
    IFNULL(LEAD(name) OVER(ORDER BY id_psg),
      FIRST_VALUE(name) OVER(ORDER BY id_psg ROWS UNBOUNDED PRECEDING)
    )
  FROM passenger
)
SELECT name, prev, next FROM p
WHERE id_psg IN (
  SELECT id_psg FROM q WHERE ctr = (SELECT MAX(ctr) FROM q)
);



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=131

Выбрать из таблицы Trip такие города, названия которых содержат минимум 2 разные буквы из списка (a,e,i,o,u) и все имеющиеся в названии буквы из этого списка встречаются одинаковое число раз. 
*/

SELECT town
FROM (
  SELECT *, 
    LENGTH(town) - LENGTH(REPLACE(town, a, '')) n
  FROM (
    SELECT LOWER(town_from) town FROM trip
    UNION
    SELECT LOWER(town_to) FROM trip
  ) q0
  CROSS JOIN (
    SELECT 'a' UNION 
    SELECT 'e' UNION 
    SELECT 'i' UNION 
    SELECT 'o' UNION 
    SELECT 'u'
  ) q1
) q
WHERE n <> 0
GROUP BY town
HAVING COUNT(n) > 1 AND MIN(n) = MAX(n);



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=133

Пусть имеется некоторое подмножество S множества целых чисел. Назовем "горкой с вершиной N" последовательность чисел из S, в которой числа, меньшие N, выстроены (слева направо без разделителей) сначала возрастающей цепочкой, а потом – убывающей цепочкой, и значением N между ними.
Например , для S = {1, 2, …, 10} горка с вершиной 5 представляется такой последовательностью: 123454321. При S, состоящем из идентификаторов всех компаний, для каждой компании построить "горку", рассматривая ее идентификатор в качестве вершины.
Считать идентификаторы положительными числами и учесть, что в базе нет данных, при которых количество цифр в "горке" может превысить 70.
Вывод: id_comp, "горка" 
*/

SELECT id_comp, 
  CONCAT(
    REPLACE(s, '.', ''),
    REPLACE(REPLACE(r, id_comp, ''), '.', '')
  ) hill
FROM (
  SELECT id_comp, 
    SUBSTRING_INDEX(s, '.', ROW_NUMBER() OVER(ORDER BY id_comp)) s,
    SUBSTRING_INDEX(r, '.', -ROW_NUMBER() OVER(ORDER BY id_comp)) r
  FROM company, (
    SELECT 
      GROUP_CONCAT(id_comp ORDER BY id_comp SEPARATOR '.') s,
      GROUP_CONCAT(id_comp ORDER BY id_comp DESC SEPARATOR '.') r
    FROM company
  ) q
) q;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=138

Выведите имена пассажиров, которые побывали в наибольшем количестве разных городов, включая города отправления.
*/

WITH 
t(id_psg, town_from, town_to) AS(
  SELECT id_psg, town_from, town_to 
  FROM trip JOIN pass_in_trip USING(trip_no)
),
p(id_psg, town) AS(
  SELECT id_psg, town_from FROM t
  UNION
  SELECT id_psg, town_to town FROM t
),
q(id_psg, ctr) AS(
  SELECT id_psg, COUNT(DISTINCT town) 
  FROM p 
  GROUP BY id_psg
)
SELECT name 
FROM q JOIN passenger USING(id_psg)
WHERE ctr = (SELECT MAX(ctr) FROM q);


