use fraud



select * INTO fraud_all
from fraudTrain$
UNION ALL 
SELECT * 
FROM fraudTest$

SELECT * FROM fraud_all

UPDATE fraud_all
SET merchant = REPLACE(merchant, 'fraud_', '')

SELECT *
FROM fraud_all
WHERE is_fraud = 1



---------------------------------Main key points
--- 1) count number of people effected by fraud
SELECT 
	COUNT(is_fraud) as fraudCount
FROM fraud_all
WHERE is_fraud = 1


--- 2) $ of total fraud
SELECT 
	CAST(ROUND(SUM(amt), 2) AS DECIMAL (10,2)) as fraudAmountTotal
FROM fraud_all
WHERE is_fraud = 1


--- 3) % of transactions that are fraud compared to total US population
SELECT 
	(CAST(fraud as decimal (20,8))/ CAST(totalTarns AS decimal (20,8))) as fraudperc
FROM (
	SELECT 
		COUNT(trans_num) as totalTarns,
		COUNT(CASE WHEN is_fraud = 1 THEN 1 END) as fraud
	FROM fraud_all
	) AS perCount

---- 4) total trans
select count(trans_num) as totalTrans
FROM fraud_all

------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------State Total's
--- where in the us has the most fraud
SELECT 
	state,
	SUM(amt) as amtFraud
FROM fraud_all
WHERE is_fraud = 1
GROUP BY state
ORDER BY amtFraud DESC

--- state with most fraud 
SELECT 
	state,
	COUNT(is_fraud) AS fraudCount
FROM fraud_all
WHERE is_fraud = 1
GROUP BY state
ORDER BY fraudCount DESC 

------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------Generation State
---- Average Age Base on State
SELECT 
	state, 
	AVG(DATEDIFF(YEAR, dob, GETDATE () ) ) as avgAge
FROM fraud_all
WHERE dob <= GETDATE()
GROUP BY state

----State Generation Count 
WITH stateFraud AS (

SELECT 
	state,
	SUM(is_fraud) as totalfraudCout
FROM fraud_all
WHERE is_fraud = 1
GROUP BY state


),

gens_cte AS (
SELECT 
	dob,
	state, 
	CASE 
		WHEN year(dob) <= 1964 then 'Baby Boomer' 
		WHEN year(dob) BETWEEN 1965 AND 1980 then 'Gen X'
		WHEN year(dob) BETWEEN 1981 AND 1996 then 'Millennial'
		WHEN year(dob) BETWEEN 1997 AND 2012 then 'Gen Z'
	END as gens
	FROM fraud_all
	WHERE is_fraud = 1

),

fraudGenCount as (
	SELECT 
		g.state,
		g.gens,
		COUNT(*) AS fraudCountGens
	FROM gens_cte AS g
	GROUP BY g.state, g.gens
),

avgAge_cte as ( 

	SELECT 
	state, 
	AVG(DATEDIFF(YEAR, dob, GETDATE () ) ) as avgAge
FROM fraud_all
WHERE dob <= GETDATE()
GROUP BY state

)

SELECT 
	sf.state,
	fg.gens,
	fg.fraudCountGens,
	avgAge_cte.avgAge,
	sf.totalfraudCout
FROM stateFraud AS sf
JOIN fraudGenCount AS fg 
	ON sf.state = fg.state
JOIN avgAge_cte
	ON sf.state = avgAge_cte.state
ORDER BY totalfraudCout DESC




---Total Gen fraud
SELECT 
	gens,
	COUNT(*) as fraudCount,
		(SELECT COUNT(*)
		FROM fraud_all
		WHERE is_fraud = 1) as totalFraud
FROM (
	SELECT 
	dob,
	CASE 
		WHEN year(dob) <= 1964 then 'Baby Boomer' 
		WHEN year(dob) BETWEEN 1965 AND 1980 then 'Gen X'
		WHEN year(dob) BETWEEN 1981 AND 1996 then 'Millennial'
		WHEN year(dob) BETWEEN 1997 AND 2012 then 'Gen Z'
	END as gens
	FROM fraud_all
	WHERE is_fraud = 1
) as genCount
GROUP BY gens
ORDER BY fraudCount DESC

------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------Generation Category
--- what catergory has the most fraud
SELECT category,
	SUM(amt) as catCount
FROM fraud_all
WHERE is_fraud = 1
GROUP BY category
ORDER BY catCount DESC

---Gens Category and amount in category
WITH merchFraud AS (

SELECT 
	category,
	SUM(amt) as totalfraudamt
FROM fraud_all
WHERE is_fraud = 1
GROUP BY category

),

gens_cte AS (
SELECT
	category,
	dob, 
	CASE 
		WHEN year(dob) <= 1964 then 'Baby Boomer' 
		WHEN year(dob) BETWEEN 1965 AND 1980 then 'Gen X'
		WHEN year(dob) BETWEEN 1981 AND 1996 then 'Millennial'
		WHEN year(dob) BETWEEN 1997 AND 2012 then 'Gen Z'
	END as gens,
		amt
	FROM fraud_all
	WHERE is_fraud = 1

),

fraudGenAmount as (
	SELECT 
		g.category, 
		g.gens,
		SUM(g.amt) AS fraudAmount
	FROM gens_cte AS g
	GROUP BY g.category, g.gens
)

SELECT 
	fa.category,
	fa.gens,
	fa.fraudAmount,
	mf.totalfraudamt
FROM fraudGenAmount fa
JOIN merchFraud mf
	ON fa.category = mf.category
ORDER BY mf.totalfraudamt DESC, fa.fraudAmount DESC


select * from fraud_all



------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------Generation Spending Category
--Fining Range for Spending 
WITH catSize_cte AS (

	SELECT 
		MIN(amt) as minamt, 
		MAX(amt) as maxamt,
		COUNT(amt) as ta
	FROM fraud_all
	WHERE is_fraud = 1
	), 

calculate AS (
	select 
		(maxamt - minamt) / 3 AS range_
	FROM catSize_cte

	)
select range_
FROM calculate


--Putting Generation Spending into Spending Category Ranges
create view gensCat AS 

WITH gensCategory AS (

	SELECT 
			CASE 
				WHEN year(dob) <= 1964 then 'Baby Boomer' 
				WHEN year(dob) BETWEEN 1965 AND 1980 then 'Gen X'
				WHEN year(dob) BETWEEN 1981 AND 1996 then 'Millennial'
				WHEN year(dob) BETWEEN 1997 AND 2012 then 'Gen Z'
			END as gens,
			amt
		FROM fraud_all
		WHERE is_fraud = 1
),
spendCategory AS (
SELECT 
	gens,
	amt ,
	CASE 
		WHEN amt <= 456 THEN 'small'																														
		WHEN amt  BETWEEN 457 AND 913 THEN 'med'
		ELSE 'high'
	END as c
FROM gensCategory

)

SELECT 
	gens,
	SUM(amt) as total,
	c
FROM spendCategory
GROUP BY gens, c
ORDER BY total DESC

---Finding Range for Spending Totals
---If category total is below certain amount/ above certain amount put into a Grand Total Spending Category (h/m/low)
SELECT 
	(MAX(total) - MIN(total)) / 3 AS range_
FROM gensCat

--Putting Grand Totals into Grand Total Sending Category
SELECT
	gens,
	total,
	CASE 
		WHEN total <= 248690 THEN 'Small Total'
		WHEN total BETWEEN 248691 AND  497380 THEN 'Medium Total'
		ELSE 'High Total' 
	END as totalRange
	
FROM (
		SELECT
		gens,
		total,
		(MAX(total) - MIN(total)) / 3 AS range_
		FROM gensCat
		GROUP BY gens, total
	) as rangeC

ORDER BY total DESC

----- add totals together and puts them into a grand total
SELECT
    gens,
    SUM(total) AS total,
    totalRange
FROM (
    SELECT
        gens,
        total,
        CASE 
            WHEN total <= 248690 THEN 'Small Total'
            WHEN total BETWEEN 248691 AND 497380 THEN 'Medium Total'
            ELSE 'High Total' 
        END AS totalRange
    FROM gensCat
) AS categorizedTotals
GROUP BY gens, totalRange
ORDER BY total DESC;


--- Sums all categories together 
SELECT
    gens,
    SUM(total) AS totalSum,
    CASE 
        WHEN SUM(total) <= 248690 THEN 'Small Total'
        WHEN SUM(total) BETWEEN 248691 AND 497380 THEN 'Medium Total'
        ELSE 'High Total' 
    END AS totalRange
FROM gensCat
GROUP BY gens
ORDER BY totalSum DESC;

