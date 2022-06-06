/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=97

Отобрать из таблицы Laptop те строки, для которых выполняется следующее условие:
значения из столбцов speed, ram, price, screen возможно расположить таким образом, что каждое последующее значение будет превосходить предыдущее в 2 раза или более.
Замечание: все известные характеристики ноутбуков больше нуля.
Вывод: code, speed, ram, price, screen.
*/

WITH t (code, k) AS (
  SELECT code, 
    LEAD(value) OVER (PARTITION BY code ORDER BY value) / value
  FROM (
    SELECT code, speed value FROM laptop UNION ALL
    SELECT code, ram FROM laptop UNION ALL
    SELECT code, price FROM laptop UNION ALL
    SELECT code, screen FROM laptop
  ) q
)
SELECT code, speed, ram, price, screen 
FROM laptop
WHERE code IN (
	SELECT code FROM t WHERE k >= 2 GROUP BY code HAVING COUNT(*) = 3
);



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=101

Таблица Printer сортируется по возрастанию поля code.
Упорядоченные строки составляют группы: первая группа начинается с первой строки, каждая строка со значением color='n' начинает новую группу, группы строк не перекрываются.
Для каждой группы определить: наибольшее значение поля model (max_model), количество уникальных типов принтеров (distinct_types_cou) и среднюю цену (avg_price).
Для всех строк таблицы вывести: code, model, color, type, price, max_model, distinct_types_cou, avg_price. 
*/

SELECT code, model, color, type, price,
  MAX(model) OVER(PARTITION BY gr) max_model,
  MAX(type_rank) OVER(PARTITION BY gr) distinct_types,
  AVG(price) OVER(PARTITION BY gr) avg_price
FROM (
  SELECT *, IF(color = 'n', @i := @i + 1, @i) gr,
    DENSE_RANK() OVER(PARTITION BY gr ORDER BY type) type_rank
  FROM Printer, (SELECT @i := 0) r
) t
ORDER BY 1;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=105


Статистики Алиса, Белла, Вика и Галина нумеруют строки у таблицы Product.
Все четверо упорядочили строки таблицы по возрастанию названий производителей.
Алиса присваивает новый номер каждой строке, строки одного производителя она упорядочивает по номеру модели.
Трое остальных присваивают один и тот же номер всем строкам одного производителя.
Белла присваивает номера начиная с единицы, каждый следующий производитель увеличивает номер на 1.
У Вики каждый следующий производитель получает такой же номер, какой получила бы первая модель этого производителя у Алисы.
Галина присваивает каждому следующему производителю тот же номер, который получила бы его последняя модель у Алисы.
Вывести: maker, model, номера строк получившиеся у Алисы, Беллы, Вики и Галины соответственно. 
*/

SELECT *, MAX(A) OVER(PARTITION BY maker) D
FROM (
  SELECT maker, model,
    ROW_NUMBER() OVER(ORDER BY maker, model) A,
    DENSE_RANK() OVER(ORDER BY maker) B,
    RANK() OVER(ORDER BY maker) C
  FROM Product
) t;



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=123

Для каждого производителя подсчитать: сколько имеется в наличии его продуктов (любого типа) с неуникальной для этого производителя ценой и количество таких неуникальных цен.
Вывод: производитель, количество продуктов, количество цен. 
*/

SELECT maker, IFNULL(q1, 0) q1, IFNULL(q2, 0) q2
FROM (
  SELECT DISTINCT maker 
  FROM product
) m
LEFT JOIN (
  SELECT maker, SUM(cnt) q1, COUNT(cnt) q2
  FROM (
    SELECT maker, price, COUNT(price) cnt
    FROM (
      SELECT maker, price
      FROM product JOIN pc USING(model)
      UNION ALL
      SELECT maker, price
      FROM product JOIN laptop USING(model)
      UNION ALL
      SELECT maker, price
      FROM product JOIN printer USING(model)
    ) q
    GROUP BY maker, price
    HAVING cnt > 1
  ) q
  GROUP BY maker
) q
USING(maker);



/*
https://sql-ex.ru/exercises/index.php?act=learn&LN=125

Данные о продаваемых моделях и ценах (из таблиц Laptop, PC и Printer) объединить в одну таблицу LPP и создать в ней порядковую нумерацию (id) без пропусков и дубликатов.
Считать, что модели внутри каждой из трёх таблиц упорядочены по возрастанию поля code. Единую нумерацию записей LPP сделать по следующему правилу: сначала идут первые модели из таблиц (Laptop, PC и Printer), потом последние модели, далее - вторые модели из таблиц, предпоследние и т.д.
При исчерпании моделей определенного типа, нумеровать только оставшиеся модели других типов.
Вывести: id, type, model и price. Тип модели type является строкой 'Laptop', 'PC' или 'Printer'.
*/

SELECT ROW_NUMBER() OVER(ORDER BY f, g, type) id, 
  type, model, price
FROM (
  SELECT *, 
    CASE WHEN 
      g = 1 THEN ROW_NUMBER() OVER(PARTITION BY type, g ORDER BY code) 
    ELSE 
      ROW_NUMBER() OVER(PARTITION BY type, g ORDER BY code DESC) 
    END AS f   
  FROM (
    SELECT *, NTILE(2) OVER(PARTITION BY type ORDER BY code) g
    FROM (
      SELECT code, 'Laptop' type, model, price FROM laptop
      UNION
      SELECT code, 'PC', model, price FROM pc
      UNION
      SELECT code, 'Printer', model, price FROM printer
    ) q
  ) q
) q;

