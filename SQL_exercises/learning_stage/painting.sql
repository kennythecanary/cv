/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=106

Пусть v1, v2, v3, v4, ... представляет последовательность вещественных чисел - объемов окрасок b_vol, упорядоченных по возрастанию b_datetime, b_q_id, b_v_id.
Найти преобразованную последовательность P1=v1, P2=v1/v2, P3=v1/v2*v3, P4=v1/v2*v3/v4, ..., где каждый следующий член получается из предыдущего умножением на vi (при нечетных i) или делением на vi (при четных i).
Результаты представить в виде b_datetime, b_q_id, b_v_id, b_vol, Pi, где Pi - член последовательности, соответствующий номеру записи i. Вывести Pi с 8-ю знаками после запятой. 
*/

SELECT b_datetime, b_q_id, b_v_id, b_vol, 
  ROUND(IF(@i := (@i + 1) % 2 = 1, 
      @p := @p * b_vol,
      @p := @p / b_vol
  ), 8) sv
FROM utb, (SELECT @i := 0) r1, (SELECT @p := 1) r2;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=108

Реставрация экспонатов секции "Треугольники" музея ПФАН проводилась согласно техническому заданию. Для каждой записи таблицы utb малярами подкрашивалась сторона любой фигуры, если длина этой стороны равнялась b_vol.
Найти окрашенные со всех сторон треугольники, кроме равносторонних, равнобедренных и тупоугольных.
Для каждого треугольника (но без повторений) вывести три значения X, Y, Z, где X - меньшая, Y - средняя, а Z - большая сторона. 
*/

SELECT s1.b_vol a, s2.b_vol b, s3.b_vol c  
FROM
  (SELECT DISTINCT b_vol FROM utb) s1,
  (SELECT DISTINCT b_vol FROM utb) s2,
  (SELECT DISTINCT b_vol FROM utb) s3
WHERE s1.b_vol < s2.b_vol
  AND s2.b_vol < s3.b_vol
  AND (POW(s1.b_vol,2)+POW(s2.b_vol,2)-POW(s3.b_vol,2))/(2*s1.b_vol*s2.b_vol) >= 0;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=109

Вывести:
1. Названия всех квадратов черного или белого цвета.
2. Общее количество белых квадратов.
3. Общее количество черных квадратов.
*/

WITH q(q_name, col) AS(
  SELECT q_name, 'w'
  FROM utb JOIN utq ON utb.b_q_id = utq.q_id
  GROUP BY b_q_id 
  HAVING SUM(b_vol) = 765
  UNION
  SELECT q_name, 'b'
  FROM utb RIGHT JOIN utq ON utb.b_q_id = utq.q_id
  WHERE b_vol IS NULL
)
SELECT q_name,
  (SELECT COUNT(*) FROM q WHERE col = 'w') whites,
  (SELECT COUNT(*) FROM q WHERE col = 'b') blacks
FROM q;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=111

Найти НЕ белые и НЕ черные квадраты, которые окрашены разными цветами в пропорции 1:1:1. Вывод: имя квадрата, количество краски одного цвета 
*/

SELECT q_name, r Qty FROM (
  SELECT * 
  FROM (
    SELECT b_q_id, SUM(b_vol) r 
    FROM utb JOIN utv ON utb.b_v_id = utv.v_id 
    WHERE v_color = 'r' 
    GROUP BY b_q_id
  ) q1 
  JOIN (
    SELECT b_q_id, SUM(b_vol) g 
    FROM utb JOIN utv ON utb.b_v_id = utv.v_id 
    WHERE v_color = 'g' 
    GROUP BY b_q_id
  ) q2 USING (b_q_id) 
  JOIN (
    SELECT b_q_id, SUM(b_vol) b 
    FROM utb JOIN utv ON utb.b_v_id = utv.v_id 
    WHERE v_color = 'b' 
    GROUP BY b_q_id
  ) q3 USING (b_q_id) 
  WHERE r = (r + g + b) / 3 
    AND g = (r + g + b) / 3 
    AND b = (r + g + b) / 3 
    AND r + g + b < 765
  ) q
JOIN utq ON q.b_q_id = utq.q_id;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=112

Какое максимальное количество черных квадратов можно было бы окрасить в белый цвет
оставшейся краской.
*/

WITH t(remains) 
AS(
  SELECT SUM(remains)/255 
  FROM (
    SELECT v_color, 255 - SUM(IFNULL(b_vol, 0)) remains
    FROM utb RIGHT JOIN utv ON utb.b_v_id = utv.v_id
    GROUP BY v_id
    HAVING remains > 0
  ) q
  GROUP BY v_color
)
SELECT IF((SELECT COUNT(*) FROM t) = 3, FLOOR(MIN(remains)), 0) Qty
FROM t;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=113

Сколько каждой краски понадобится, чтобы докрасить все Не белые квадраты до белого цвета.
Вывод: количество каждой краски в порядке (R,G,B) 
*/

WITH 
t (b_q_id, v_color, b_vol) AS (
  SELECT b_q_id, v_color, 255-IFNULL(b_vol, 0) 
  FROM (
    SELECT b_q_id, v_color, SUM(b_vol) b_vol
    FROM utb 
      JOIN utv ON utb.b_v_id = utv.v_id
    GROUP BY b_q_id, v_color
  ) q0 RIGHT JOIN (
    SELECT DISTINCT q_id b_q_id, v_color
    FROM utq, 
      (SELECT 'r' v_color UNION SELECT 'g' UNION SELECT 'b') c
  ) q1 USING (b_q_id, v_color)
),
q (v_color, b_vol) AS (
  SELECT v_color, b_vol FROM t WHERE b_q_id IN (
    SELECT b_q_id FROM t GROUP BY b_q_id HAVING SUM(b_vol) > 0
  )
)
SELECT red, green, blue FROM (
  SELECT SUM(b_vol) red, 1 row FROM q WHERE v_color = 'r'
) q1 JOIN (
  SELECT SUM(b_vol) green, 1 row FROM q WHERE v_color = 'g'
) q2 USING (row) JOIN (
  SELECT SUM(b_vol) blue, 1 row FROM q WHERE v_color = 'b'
) q3 USING (row);



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=115

Рассмотрим равнобочные трапеции, в каждую из которых можно вписать касающуюся всех сторон окружность. Кроме того, каждая сторона имеет целочисленную длину из множества значений b_vol.
Вывести результат в 4 колонки: Up, Down, Side, Rad. Здесь Up - меньшее основание, Down - большее основание, Side - длины боковых сторон, Rad – радиус вписанной окружности (с 2-мя знаками после запятой). 
*/

SELECT u.b_vol up, d.b_vol down, s.b_vol side,
  ROUND(SQRT(POW(s.b_vol, 2)-POW((d.b_vol-u.b_vol)/2, 2))/2, 2) rad
FROM
  (SELECT DISTINCT b_vol FROM utb) u,
  (SELECT DISTINCT b_vol FROM utb) d,
  (SELECT DISTINCT b_vol FROM utb) s
WHERE u.b_vol < d.b_vol
  AND u.b_vol + d.b_vol = s.b_vol * 2;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=116

Считая, что каждая окраска длится ровно секунду, определить непрерывные интервалы времени с длительностью более 1 секунды из таблицы utB.
Вывод: дата первой окраски в интервале, дата последней окраски в интервале. 
*/

SELECT MIN(d) date_start, MAX(d) date_finish
FROM (
  SELECT d, SUM(f) OVER(ORDER BY d ROWS UNBOUNDED PRECEDING) f
  FROM (
    SELECT b_datetime d, 
      IF(IFNULL(TIMESTAMPDIFF(SECOND, LAG(b_datetime) OVER(ORDER BY b_datetime), b_datetime), 0) < 2, 0, 1) f
    FROM utb
  ) q
) q
GROUP BY f
HAVING TIMESTAMPDIFF(SECOND, date_start, date_finish) > 0;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=119

Сгруппировать все окраски по дням, месяцам и годам. Идентификатор каждой группы должен иметь вид "yyyy" для года, "yyyy-mm" для месяца и "yyyy-mm-dd" для дня.
Вывести только те группы, в которых количество различных моментов времени (b_datetime), когда выполнялась окраска, более 10.
Вывод: идентификатор группы, суммарное количество потраченной краски.
*/

WITH t(datetime, period, m, d, vol) AS(
  SELECT b_datetime, 
    YEAR(b_datetime), 
    DATE_FORMAT(b_datetime, '%Y-%m'), 
    DATE(b_datetime), b_vol
  FROM utb
)
SELECT period, SUM(vol) FROM t GROUP BY period HAVING COUNT(DISTINCT datetime) > 10
UNION
SELECT m, SUM(vol) FROM t GROUP BY m HAVING COUNT(DISTINCT datetime) > 10
UNION
SELECT d, SUM(vol) FROM t GROUP BY d HAVING COUNT(DISTINCT datetime) > 10;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=129

Предполагая, что среди идентификаторов квадратов имеются пропуски, найти минимальный и максимальный "свободный" идентификатор в диапазоне между имеющимися максимальным и минимальным идентификаторами.
Например, для последовательности идентификаторов квадратов 1,2,5,7 результат должен быть 3 и 6.
Если пропусков нет, вместо каждого искомого значения выводить NULL. 
*/

SELECT MIN(q_min) q_min, MAX(q_max) q_max
FROM (
  SELECT q_id + 1 q_min, next_id - 1 q_max
  FROM (
    SELECT q_id, LEAD(q_id) OVER(ORDER BY q_id) next_id
    FROM utq
  ) q
  WHERE next_id-q_id > 1
) q;




/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=134

Выполняется докраска квадратов до белого цвета каждым цветом по следующей схеме:
- сначала закрашиваются квадраты, для которых требуется меньше краски соответствующего цвета;
- при одинаковом необходимом количестве краски сначала закрашиваются квадраты с меньшим q_id.
Найти идентификаторы НЕ белых квадратов, оставшихся после израсходования всей краски. 
*/

SELECT q_id
FROM (
  SELECT *, 
    SUM(255-vol) OVER(PARTITION BY v_color ORDER BY vol DESC, q_id) vol_need
  FROM (
    SELECT b_q_id q_id, v_color, SUM(IFNULL(b_vol, 0)) vol
    FROM utb JOIN utv ON utb.b_v_id  = utv.v_id
    RIGHT JOIN (
      SELECT DISTINCT q_id b_q_id, v_color FROM utq, utv
    ) q USING(b_q_id, v_color)
    GROUP BY b_q_id, v_color
  ) q1
  JOIN (
    SELECT v_color, SUM(255-vol) vol_left
    FROM (
      SELECT v_id, v_color, SUM(IFNULL(b_vol, 0)) vol
      FROM utb RIGHT JOIN utv ON utb.b_v_id = utv.v_id
      GROUP BY v_id
      HAVING SUM(IFNULL(b_vol, 0)) < 255
    ) q
    GROUP BY v_color
  ) q2 USING(v_color)
) q
GROUP BY q_id
HAVING SUM(vol_need > vol_left) > 0;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=135

В пределах каждого часа, в течение которого выполнялись окраски,
найти максимальное время окраски (B_DATETIME). 
*/

SELECT MAX(b_datetime)
FROM utb
GROUP BY DATE_FORMAT(b_datetime, '%Y-%m-%d %h');


