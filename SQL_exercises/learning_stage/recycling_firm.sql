/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=99

Рассматриваются только таблицы Income_o и Outcome_o. Известно, что прихода/расхода денег в воскресенье не бывает.
Для каждой даты прихода денег на каждом из пунктов определить дату инкассации по следующим правилам:
1. Дата инкассации совпадает с датой прихода, если в таблице Outcome_o нет записи о выдаче денег в эту дату на этом пункте.
2. В противном случае - первая возможная дата после даты прихода денег, которая не является воскресеньем и в Outcome_o не отмечена выдача денег сдатчикам вторсырья в эту дату на этом пункте.
Вывод: пункт, дата прихода денег, дата инкассации.
*/

WITH RECURSIVE 
t1 (point, date) AS (
  /* Выборка для 1-го правила */
  SELECT point, date
  FROM income_o LEFT JOIN outcome_o USING (point, date)
  WHERE `out` IS NULL
),
t2 (point, date) AS (
  /* Выборка для 2-го правила */
  SELECT point, date
  FROM income_o LEFT JOIN outcome_o USING (point, date)
  WHERE `out` IS NOT NULL
),
t AS (
  /* Интервал с датами от минимальной до максимальной в таблице outcome_o */
  SELECT MIN(date) dt FROM outcome_o
  UNION
  SELECT DATE_ADD(t.dt, INTERVAL 1 DAY) 
  FROM t 
  WHERE DATE_ADD(t.dt, INTERVAL 1 DAY) <= (
    SELECT DATE_ADD(MAX(date), INTERVAL 2 DAY) FROM outcome_o
  )
),
t0 (point, date) AS (
  /* Даты из таблица t, кроме воскресений и дат из таблицы outcome_o */
  SELECT dp.point, t.dt
  FROM t CROSS JOIN (SELECT DISTINCT point FROM outcome_o) dp
  LEFT JOIN outcome_o ou 
    ON t.dt = ou.date AND ou.point = dp.point
  WHERE ou.date IS NULL 
    AND DAYNAME(dt) <> 'Sunday'
)
SELECT point, t2.date DP, t0.date DI
FROM t0 RIGHT JOIN t2 USING (point)
WHERE DATEDIFF(t0.date, t2.date) > 0
GROUP BY point, t2.date
UNION
SELECT point, date, date FROM t1
ORDER BY 1,2;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=100

Написать запрос, который выводит все операции прихода и расхода из таблиц Income и Outcome в следующем виде:
дата, порядковый номер записи за эту дату, пункт прихода, сумма прихода, пункт расхода, сумма расхода.
При этом все операции прихода по всем пунктам, совершённые в течение одного дня, упорядочены по полю code, и так же все операции расхода упорядочены по полю code.
В случае, если операций прихода/расхода за один день было не равное количество, выводить NULL в соответствующих колонках на месте недостающих операций.
*/

WITH t (date, point, inc, tab, pos) AS(
  SELECT date, point, inc, tab, 
    ROW_NUMBER() OVER(PARTITION BY date, tab ORDER BY code)
  FROM (
    SELECT *, 'inc' tab FROM income UNION ALL
    SELECT *, 'out' FROM outcome
  ) ut
)
SELECT date, pos, 
  t1.point inc_point, t1.inc, 
  t2.point out_point, t2.inc `out`
FROM
(SELECT DISTINCT date, pos FROM t) t0
LEFT JOIN
(SELECT * FROM t WHERE tab = 'inc') t1 USING (date, pos)
LEFT JOIN
(SELECT * FROM t WHERE tab = 'out') t2 USING (date, pos);



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=128

Определить лидера по сумме выплат в соревновании между каждой существующей парой пунктов с одинаковыми номерами из двух разных таблиц - outcome и outcome_o - на каждый день, когда осуществлялся прием вторсырья хотя бы на одном из них.
Вывод: Номер пункта, дата, текст:
- "once a day", если сумма выплат больше у фирмы с отчетностью один раз в день;
- "more than once a day", если - у фирмы с отчетностью несколько раз в день;
- "both", если сумма выплат одинакова. 
*/

SELECT point, date, 
  CASE 
    WHEN IFNULL(SUM(f.out),0) > IFNULL(o.out,0) THEN 'more than once a day'
    WHEN IFNULL(SUM(f.out),0) < IFNULL(o.out,0) THEN 'once a day'
    ELSE 'both'
  END AS 'leader'
FROM (
  SELECT point, date FROM outcome
  UNION
  SELECT point, date FROM outcome_o
) q0
JOIN (
  SELECT DISTINCT point FROM outcome JOIN outcome_o USING(point)
) q1 USING(point)
LEFT JOIN outcome f USING(point, date)
LEFT JOIN outcome_o o USING(point, date)
GROUP BY point, date;

