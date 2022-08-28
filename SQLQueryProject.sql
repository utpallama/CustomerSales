--- Data 
Select * 
From PortfolioDatabase.dbo.sales_data_sample

-- (1) Check for unique values
Select distinct status 
From PortfolioDatabase.dbo.sales_data_sample

Select distinct year_id 
From PortfolioDatabase.dbo.sales_data_sample

Select distinct PRODUCTLINE 
From PortfolioDatabase.dbo.sales_data_sample

Select distinct COUNTRY 
From PortfolioDatabase.dbo.sales_data_sample

Select distinct DEALSIZE 
From PortfolioDatabase.dbo.sales_data_sample

Select distinct TERRITORY 
From PortfolioDatabase.dbo.sales_data_sample


-- (2) Group sales by productline
Select PRODUCTLINE, sum(sales) as Sales
From PortfolioDatabase.dbo.sales_data_sample
Group by PRODUCTLINE
Order by 2 asc

-- (3) Group sales by YearId
Select YEAR_ID, sum(sales) as Sales
From PortfolioDatabase.dbo.sales_data_sample
Group by YEAR_ID
order by 2 asc

-- (4) Group sales by DEALSIZE
Select DEALSIZE, sum(sales) as Sales
From PortfolioDatabase.dbo.sales_data_sample
Group by DEALSIZE
order by 2 asc


-- (5) Find what the best month for sales in the given year was? And, how much was earned that month? 
Select  MONTH_ID, sum(sales) as Sales, count(ORDERNUMBER) as Frequency
From PortfolioDatabase.dbo.sales_data_sample
Where YEAR_ID = 2005
Group by  MONTH_ID
Order by 2 asc


-- (5.1) May was the best selling month. What product did they sell in May?
Select  MONTH_ID, PRODUCTLINE, sum(sales) as Sales, count(ORDERNUMBER) as Frequency
From PortfolioDatabase.dbo.sales_data_sample
Where YEAR_ID = 2005 and MONTH_ID = 5
Group by MONTH_ID, PRODUCTLINE
Order by 3 asc


-- (6) What city has the highest number of sales in the UK?
Select City, sum(sales) as Revenue
From PortfolioDatabase.dbo.sales_data_sample
Where country = 'UK'
Group by City
Order by 2 asc


--- (7) What is the best product in UK?
Select Country, PRODUCTLINE, sum(sales) as Revenue
From PortfolioDatabase.dbo.sales_data_sample
Where country = 'UK'
Group by  country, PRODUCTLINE
Order by 3 asc


-- (8) Who is the best customer? RFM analysis
-- Recency = how long ago their last purchase was
-- Frequency = how often they purchase
-- Monetary value = how much they spent
-- In this dataset our Recency = last order date, Frequency = count of total orders, Monetary value = total spend
-- DATEDIFF = gives the difference between the two dates. So in this case were doing MaxOrderDate - LastOrderDate to find the number of days between them.
-- NTILE = distributes rows into specified number of groups. NTILE(4) would seperate the rows into 4 groups.
-- ;with rfm = were putting the results into rfm. 
-- DROP TABLE = creates a temp table. We have basically created a temp table where we can select from. And it deletes the table everyone its ran. Instead of running everything, now we can just call the #rfm table.

DROP TABLE IF EXISTS #rfm
;with rfm as
(
	Select CUSTOMERNAME, 
			sum(sales) as MonetaryValue,
			avg(sales) as AverageMonetaryValue,
			count(ORDERNUMBER) as Frequency,
			max(ORDERDATE) as LastOrderDate,
			(Select max(ORDERDATE) From PortfolioDatabase.dbo.sales_data_sample) as MaxOrderDate,
			DATEDIFF(DD, max(ORDERDATE), (Select max(ORDERDATE) From PortfolioDatabase.dbo.sales_data_sample)) as Recency
	From PortfolioDatabase.dbo.sales_data_sample
	Group by CUSTOMERNAME
),
-- How the 4 groups are split 
-- rfmRecency = the closer the date is between MaxOrderDate and LastOrderDate, the bigger the value
-- rfmFrequencey = the higher the "Frequency" the bigger the rfmFrequency is
-- rfmMonetary = the bigger the "MonetaryValue" the bigger the rfmMonetary is
-- rfm_calc = Saved in another cte, meaning we created another temp table
rfmCalculate as
(
	Select r.*,
			NTILE(4) OVER (order by Recency desc) rfmRecency,
			NTILE(4) OVER (order by Frequency) rfmFrequency,
			NTILE(4) OVER (order by MonetaryValue) rfmMonetary
	From rfm r
)
Select calc.*, rfmRecency + rfmFrequency + rfmMonetary as rfmCellAdd, 
	   cast(rfmRecency as varchar) + cast(rfmFrequency as varchar) + cast(rfmMonetary  as varchar) as rfmStringAdd -- (Puts the 3 values together, not add)
into #rfm
From rfmCalculate calc

-- Now lets categorise customers
-- To find the meaning behind the numbers, look athe the explanation of the rfmRecency,rfmFrequencey,rfmMonetary above
Select CUSTOMERNAME , rfmRecency, rfmFrequency, rfmMonetary, rfmStringAdd,
		case 
			when rfmStringAdd in (311, 411, 331) then 'New Customers'
			when rfmStringAdd in (323, 333,321, 422, 332, 432) then 'Active/Often Customers' --(Customers who buy frequently and recently, but they buy at low price points)
			when rfmStringAdd in (111, 141, 112 , 114, 122, 123, 132, 211, 212, 121) then 'Lost Customers' 
			when rfmStringAdd in (133, 134, 143, 244, 334, 343, 344, 144) then 'We cannot lose these customers, their slipping away' -- (These customers are big spenders, but who haven’t purchased lately) 
			when rfmStringAdd in (433, 434, 443, 444) then 'Loyal Customers'
			when rfmStringAdd in (222, 223, 233, 322) then 'Potential churners'
		end rfmCustomers
From #rfm



-- (9) What products are most frequently sold together?
Select distinct OrderNumber, stuff(

			(Select ',' + PRODUCTCODE
			From PortfolioDatabase.dbo.sales_data_sample k
			Where ORDERNUMBER in 
				(
					Select ORDERNUMBER
					From (
							Select ORDERNUMBER, count(*) as rk  -- rk means the number of times the ORDERNUMBER ordered something.
							From PortfolioDatabase.dbo.sales_data_sample
							Where STATUS = 'Shipped'
							Group by ORDERNUMBER
					)n 
					Where rk = 3      -- There are 13 orders where 3 items were ordered
				)
				and k.ORDERNUMBER = w.ORDERNUMBER
				for xml path (''))
				, 1, 1, '') ProductCodes  -- using xml path to remove the "," that was in the start of the ProductCodes, so we replaced it with nothing.

From PortfolioDatabase.dbo.sales_data_sample w
Order by 2 desc