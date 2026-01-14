/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: 
 * Дата: 
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
WITH a AS (
SELECT
	COUNT(id)::decimal AS players,
	SUM(payer)::decimal AS donaters
FROM
	fantasy.users)
SELECT
	players,
	donaters,
	donaters / players AS donaters_percentage
FROM
	a
;


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
SELECT
	race.race,
	SUM(users.payer) AS donaters,
	(SUM(users.payer)::decimal / COUNT(users.id)::decimal) * 100 AS donaters_percentage
FROM
	fantasy.users
JOIN fantasy.race ON
	users.race_id = race.race_id
GROUP BY
	race.race
;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь

WITH stats AS (
SELECT
	COUNT(amount) AS count,
	SUM(amount) AS total,
	MIN(amount) AS min,
	MAX(amount) AS max,
	AVG(amount) AS average,
	(
	SELECT
		PERCENTILE_CONT(0.5) WITHIN GROUP (
		ORDER BY amount)
	FROM
		fantasy.events) AS median,
	STDDEV(amount) AS standard_deviation
FROM
	fantasy.events
)
SELECT
	count,
	total,
	min,
	max,
	average,
	median,
	standard_deviation
FROM
	stats;

-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
WITH a AS 
(
SELECT
	id,
	amount
FROM
	fantasy.events
WHERE
	amount = 0
	OR amount IS NULL )
SELECT
	COUNT(a.amount) AS zero_buys,
	(COUNT(a.amount)::decimal / (
	SELECT
		COUNT(*)
	FROM
		fantasy.events)) * 100 AS zero_buys_share
FROM
	a
;

-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь
WITH total_sells AS (
SELECT
	COUNT(transaction_id) AS total,
	COUNT(DISTINCT id) AS buyers
FROM
	fantasy.events
WHERE
	amount > 0
)
SELECT
	items.game_items,
	COUNT(events.transaction_id) AS sells,
	(COUNT(events.transaction_id)::decimal / (
	SELECT
		total
	FROM
		total_sells)) * 100 AS relative_sells,
	COUNT(DISTINCT events.id)::decimal / (
	SELECT
		buyers
	FROM
		total_sells) * 100 AS relative_buyers 
FROM
	fantasy.items
LEFT JOIN fantasy.events ON
	events.item_code = items.item_code
WHERE
	events.amount > 0
GROUP BY
	items.game_items
ORDER BY
	COUNT(events.id)::decimal / (
	SELECT
		buyers
	FROM
		total_sells) DESC;


-- Часть 2. Решение ad hoc-задачbи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH  a AS  (
SELECT 
	users.id,
	race.race,
	users.payer,
	events.amount
FROM 
	fantasy.users
JOIN  fantasy.race ON 
	users.race_id = race.race_id
LEFT  JOIN  fantasy.events ON 
	users.id = fantasy.events.id 
),
b AS  (
SELECT 
	race,
	COUNT(DISTINCT  id) AS  players_amount
FROM 
	a
GROUP  BY 
	race 
),
c AS  (
SELECT 
	id,
	race,
	payer,
	SUM(amount) AS  total_purchase_amount,
	COUNT(*) AS  total_transactions
FROM 
	a
WHERE 
	amount > 0
GROUP  BY 
	id,
	race,
	payer 
)
SELECT 
	b.race,
	b.players_amount,
	COUNT(c.id) AS players_with_purchases,
	(COUNT(CASE WHEN c.payer = 1 THEN c.id END))::decimal / COUNT( c.id) * 100 AS percentage_paying_players_among_purchasers,
 (COUNT(c.id))::decimal / b.players_amount * 100 AS percentage_players_with_purchases,
(SUM(c.total_purchase_amount) / NULLIF(SUM(c.total_transactions), 0))::decimal AS avg_purchase_amount_per_transaction,
 (SUM(c.total_purchase_amount) / NULLIF(COUNT( c.id), 0))::decimal AS avg_total_purchase_amount_per_player,
 (SUM(c.total_transactions) / NULLIF(COUNT(c.id), 0))::decimal AS avg_transactions_per_player 
 FROM b  
 LEFT JOIN c ON b.race = c.race 
 GROUP BY b.race, b.players_amount 
 ORDER BY b.race;
