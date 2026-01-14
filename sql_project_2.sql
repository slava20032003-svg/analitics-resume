--Задача 1
WITH limits AS(
  SELECT
  		PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
   FROM real_estate.flats
 ), 
 filtered_id AS(
  SELECT id
   FROM real_estate.flats
   WHERE total_area < (SELECT total_area_limit FROM limits)
   AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
   AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
   AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
   AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
segments AS(
	SELECT *,
	CASE
    	WHEN c. city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
    	ELSE 'ЛенОбл'
    		END AS "Регион",
    CASE
    	WHEN a.days_exposition BETWEEN 1 AND 30 THEN 'до месяца'
    	WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'до трех месяцев'
   	 	WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'до полугода'
    	ELSE 'более полугода'
    		END AS "Сегмент активности"   
   FROM real_estate.advertisement AS a
   LEFT JOIN real_estate.flats f USING(id)				
   LEFT JOIN real_estate. city c USING (city_id)
	WHERE id IN (SELECT * FROM filtered_id)         	 	
   	AND days_exposition IS NOT NULL
    AND type_id='F8EM'									
    AND a. last_price > 0
    AND f.total_area > 0
)            
SELECT "Регион",
       "Сегмент активности",
	   COUNT(*) as "Кол-во объявлений",   																		
       round (AVG (last_price:: numeric / nullif(total_area, 0)::numeric), 0) AS "Средняя стоимость кв. метра",
       round (AVG (total_area::numeric), 2) AS "Средняя площадь",
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS "Медиана кол-ва комнат",
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS "Медиана кол-ва балконов",
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY FLOOR) AS "Медиана этажности"
FROM segments
GROUP BY "Регион", "Сегмент активности"
ORDER BY  "Регион" desc;

--Задача 2 
WITH limits AS(
  SELECT
  		PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
   FROM real_estate.flats
 ), 
filtered_id as (select id, total_area
					from real_estate.flats 
					where total_area < (select total_area_limit from limits)
					and (rooms < (select rooms_limit from limits) or rooms is null) 
					and (balcony < (select balcony_limit from limits) or balcony is null)
					and ((ceiling_height < (select ceiling_height_limit_h from limits)
							and ceiling_height > (select ceiling_height_limit_l from limits)) or ceiling_height is null)),
exposition_end as (select count(a.id) as count_exposition_end,
					extract (month from (a.first_day_exposition) + interval '1 day' * a.days_exposition) as month_end
					from real_estate.flats f 
					join real_estate.advertisement a on f.id = a.id                   
					where f.id in (select id from filtered_id)
					and a.days_exposition is not null 
					and type_id='F8EM'  -- фильтр на города 
					group by month_end) ,
exposition_in as (select count(a.id) as count_exposition_in, 
avg(a.days_exposition) as avg_days, 
avg(f.total_area) as avg_area, avg(a.last_price::numeric / nullif(f.total_area, 0)) as avg_price_for_metr,
					extract (month from a.first_day_exposition) as month_in
					from real_estate.flats f 
					join real_estate.advertisement a on f.id = a.id
					where a.id in (select id from filtered_id) 
					and a.days_exposition is not null
					group by extract (month from a.first_day_exposition)--a.id
					),
month as (select generate_series(1, 12) as month)
select 
case
when ei.month_in = 1 then 'январь'
when ei.month_in = 2 then 'февраль'
when ei.month_in = 3 then 'март'
when ei.month_in = 4 then 'апрель'
when ei.month_in = 5 then 'май'
when ei.month_in = 6 then 'июнь'
when ei.month_in = 7 then 'июль'
when ei.month_in = 8 then 'август'
when ei.month_in = 9 then 'сентябрь'
when ei.month_in = 10 then 'октябрь'
when ei.month_in = 11 then 'ноябрь'
else 'декабрь'
end as "Публикацияm",
		ei.count_exposition_in as "Кол-во публикаций", --ei.month_in as "Месяц публикации", 
       dense_rank () over (order by ei.count_exposition_in) as "Ранг публикаций",
       ee.month_end as "Месяц снятия публикации", ee.count_exposition_end as "Кол-во снятых публикаций", 
       dense_rank () over (order by ee.count_exposition_end) as "Ранг снятий", 
       coalesce(ei.avg_days, 0) as "Средний срок существования", 
       coalesce(ei.avg_area, 0) as "Средняя площадь",
       coalesce(ei.avg_price_for_metr, 0) "Средняя стоимость кв. метра"
from month m 
left join exposition_end ee on ee.month_end = m.month 
left join exposition_in ei on ei.month_in = m.month
group by m.month, ei.month_in, ee.month_end, ei.count_exposition_in, ee.count_exposition_end, ei.avg_days, ei.avg_area, ei.avg_price_for_metr
order by ei.month_in;

-- Задача 3 
with a as (select c.city as город, count(f.id) as "Кол-во объявлений"
from real_estate.flats f 
left join real_estate.city c on c.city_id = f.city_id
group by c.city)
select avg("Кол-во объявлений") as "Среднее кол-во объявлени" -- 77.5
from a     

;

WITH limits AS(
  SELECT
  		PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
   FROM real_estate.flats
 ), 
 filtered_id AS(
  SELECT id
   FROM real_estate.flats
   WHERE total_area < (SELECT total_area_limit FROM limits)
   AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
   AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
   AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
   AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
   and city_id <> '6X8I' --исключаем Санкт-Петербург из выборки
)
SELECT 
    *,
    RANK() OVER (ORDER BY "Кол-во объявлений" DESC) AS "Ранг по активности"
FROM (
    SELECT 
        c.city AS "Город", 
        ROUND(count(case when a.days_exposition is not null then 1 end)::numeric / count(a.id) * 100, 2) as "Доля снятий",
        COUNT(f.id) AS "Кол-во объявлений", 
        ROUND(AVG(a.last_price::numeric / NULLIF(f.total_area, 0)::numeric), 0) AS "Средняя стоимость кв. метра",
        ROUND(AVG(f.total_area::numeric), 2) AS "Средняя площадь",
        ROUND(AVG(a.days_exposition::numeric), 2) as "Продолжительность публикации",
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.rooms) AS "Медиана кол-ва комнат",
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.balcony) AS "Медиана кол-ва балконов",
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.FLOOR) AS "Медиана этажности" 
    FROM 
        real_estate.flats f
    LEFT JOIN 
        real_estate.advertisement a ON a.id = f.id
    LEFT JOIN 
        real_estate.city c ON c.city_id = f.city_id
    WHERE f.id IN (SELECT * FROM filtered_id)
    GROUP BY 
        c.city 
    HAVING 
        COUNT(f.id) > 77.5 -- среднее количество объявлений 
) AS subquery
ORDER BY 
    "Доля снятий" desc 
;

select distinct city_id, city 
from real_estate.city c 
where city = 'Санкт-Петербург'  -- 6X8I