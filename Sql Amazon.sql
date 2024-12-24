use business;
SET SQL_SAFE_UPDATES = 0;
-- 16.Calculate the rolling 3-month average revenue for each product category. 
WITH MonthlyRevenue AS (
    SELECT 
        DATE_FORMAT(OrderDate, '%Y-%m') AS RevenueMonth,  -- Extract year and month
        Product_Category,
        SUM(Sale_Price) AS TotalRevenue
    FROM 
        orders
    GROUP BY 
        RevenueMonth, Product_Category
),
RollingRevenue AS (
    SELECT 
        RevenueMonth,
        Product_Category,
        TotalRevenue,
        AVG(TotalRevenue) OVER (
            PARTITION BY Product_Category 
            ORDER BY RevenueMonth 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW  -- Look at the current month and two previous months
        ) AS Rolling3MonthAverageRevenue
    FROM 
        MonthlyRevenue
)

SELECT 
    RevenueMonth,
    Product_Category,
    TotalRevenue,
    Rolling3MonthAverageRevenue
FROM 
    RollingRevenue
ORDER BY 
    Product_Category, RevenueMonth;

-- 14. 14.	Identify the top 5 most valuable customers using a composite score that combines three key metrics: 
WITH CustomerMetrics AS (
    SELECT 
        CustomerID,
        SUM(Sale_Price) AS TotalRevenue,                         -- Total Revenue
        COUNT(OrderID) AS OrderFrequency,                       -- Order Frequency
        SUM(Sale_Price) / COUNT(OrderID) AS AverageOrderValue    -- Average Order Value
    FROM 
        orders
    GROUP BY 
        CustomerID
),
CustomerCompositeScore AS (
    SELECT 
        CustomerID,
        TotalRevenue,
        OrderFrequency,
        AverageOrderValue,
        -- Composite score calculation based on the given weights
        (0.5 * TotalRevenue) + (0.3 * OrderFrequency) + (0.2 * AverageOrderValue) AS CompositeScore
    FROM 
        CustomerMetrics
)
-- Rank the customers based on the composite score and select the top 5
SELECT 
    CustomerID,
    TotalRevenue,
    OrderFrequency,
    AverageOrderValue,
    CompositeScore
FROM 
    CustomerCompositeScore
ORDER BY 
    CompositeScore DESC
LIMIT 5;


-- 15. month-over-month growth rate in total revenue across the entire dataset. 
WITH MonthlyRevenue AS (
    SELECT 
        DATE_FORMAT(OrderDate, '%Y-%m') AS Month,  -- Format date to Year-Month
        SUM(Sale_Price) AS TotalRevenue  -- Sum of SalePrice as TotalRevenue
    FROM 
        orders
    GROUP BY 
        Month
),

RevenueGrowth AS (
    SELECT 
        Month,
        TotalRevenue,
        LAG(TotalRevenue) OVER (ORDER BY Month) AS PreviousMonthRevenue,  -- Get previous month's revenue
        (TotalRevenue - LAG(TotalRevenue) OVER (ORDER BY Month)) / LAG(TotalRevenue) OVER (ORDER BY Month) * 100 AS GrowthRate  -- Calculate growth rate
    FROM 
        MonthlyRevenue
)

SELECT 
    Month,
    TotalRevenue,
    PreviousMonthRevenue,
    GrowthRate
FROM 
    RevenueGrowth
WHERE 
    PreviousMonthRevenue IS NOT NULL  -- Exclude the first month which has no previous month
ORDER BY 
    Month;



-- 17. Update the Sale Price for customers with at least 10 orders
WITH CustomerOrders AS (
    SELECT CustomerID
    FROM orders
    GROUP BY CustomerID
    HAVING COUNT(OrderID) >= 10
)

UPDATE orders
SET Sale_Price = Sale_Price * 0.85
WHERE CustomerID IN (SELECT CustomerID FROM CustomerOrders);

-- 18. the average number of days between consecutive orders for customers who have placed at least five orders
WITH CustomerOrders AS (
    SELECT 
        CustomerID,
        OrderDate,
        ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS OrderRank  -- Assign a rank to each order for a customer
    FROM 
        orders
    WHERE 
        CustomerID IN (
            SELECT CustomerID
            FROM orders
            GROUP BY CustomerID
            HAVING COUNT(OrderID) >= 5  -- Filter customers with at least 5 orders
        )
),

OrderDifferences AS (
    SELECT 
        CO1.CustomerID,
        DATEDIFF(CO2.OrderDate, CO1.OrderDate) AS DaysBetween  -- Calculate the difference in days
    FROM 
        CustomerOrders CO1
    JOIN 
        CustomerOrders CO2 ON CO1.CustomerID = CO2.CustomerID AND CO1.OrderRank = CO2.OrderRank - 1  -- Join to get the next order
)

SELECT 
    AVG(DaysBetween) AS AverageDaysBetweenOrders  -- Calculate the average of days between orders
FROM 
    OrderDifferences
WHERE 
    DaysBetween IS NOT NULL;  -- Exclude any null values

SELECT CustomerID, COUNT(OrderID) AS OrderCount
FROM orders
GROUP BY CustomerID
HAVING COUNT( DISTINCT OrderID) >= 1;


-- 19. customers who have generated revenue that is more than 30% higher than the average revenue per customer. 
WITH CustomerRevenue AS (
    SELECT 
        CustomerID,
        SUM(Sale_Price) AS TotalRevenue
    FROM 
        orders
    GROUP BY 
        CustomerID
),
AverageRevenue AS (
    SELECT 
        AVG(TotalRevenue) AS AvgRevenue
    FROM 
        CustomerRevenue
)

SELECT 
    CR.CustomerID,
    CR.TotalRevenue,
    AR.AvgRevenue,
    (CR.TotalRevenue - AR.AvgRevenue) AS RevenueDifference
FROM 
    CustomerRevenue CR,
    AverageRevenue AR
WHERE 
    CR.TotalRevenue > AR.AvgRevenue * 1.3;  -- 30% higher than average revenue
 
-- 20. the top 3 product categories that have shown the highest increase in sales over the past year compared to the previous year. 
WITH SalesByCategory AS (
    SELECT 
        Product_Category,
        YEAR(OrderDate) AS OrderYear,
        SUM(Sale_Price) AS TotalSales
    FROM 
        orders
    GROUP BY 
        Product_Category, YEAR(OrderDate)
),

SalesComparison AS (
    SELECT 
        CurrentYear.Product_Category,
        CurrentYear.TotalSales AS CurrentYearSales,
        PreviousYear.TotalSales AS PreviousYearSales,
        (CurrentYear.TotalSales - COALESCE(PreviousYear.TotalSales, 0)) AS SalesIncrease
    FROM 
        SalesByCategory CurrentYear
    LEFT JOIN 
        SalesByCategory PreviousYear 
    ON 
        CurrentYear.Product_Category = PreviousYear.Product_Category 
        AND CurrentYear.OrderYear = PreviousYear.OrderYear + 1
)

SELECT 
    Product_Category,
    CurrentYearSales,
    PreviousYearSales,
    SalesIncrease
FROM 
    SalesComparison
ORDER BY 
    SalesIncrease DESC
LIMIT 3;












