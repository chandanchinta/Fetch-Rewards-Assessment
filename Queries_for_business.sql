#What are the top 5 brands by receipts scanned for most recent month?
WITH recent_month AS (
    SELECT MAX(Date) as max_date,
           Month_of_Year,
           Year
    FROM dim_Date
    GROUP BY Month_of_Year, Year
)
SELECT 
    b.Name as Brand_Name,
    COUNT(DISTINCT h.Receipt_Header_id) as Receipt_Count
FROM dim_brands b
JOIN fact_Receipt_line l ON b.Item_Id = l.Barcode
JOIN fact_Receipt_Header h ON l.Receipt_Header_id = h.Receipt_Header_id
JOIN dim_Date d ON h.Scanned_Date = d.Date
JOIN recent_month rm ON d.Month_of_Year = rm.Month_of_Year 
                    AND d.Year = rm.Year
GROUP BY b.Name
ORDER BY Receipt_Count DESC
LIMIT 5;

#How does the ranking of the top 5 brands by receipts scanned for the recent month compare to the ranking for the previous month?
WITH recent_months AS (
    -- Get the most recent month and previous month
    SELECT 
        Date,
        Month_of_Year,
        Year,
        DENSE_RANK() OVER (ORDER BY Year DESC, Month_of_Year DESC) as month_rank
    FROM dim_Date
    GROUP BY Date, Month_of_Year, Year
),
brand_rankings AS (
    -- Calculate rankings for both months
    SELECT 
        b.Name as Brand_Name,
        d.Month_of_Year,
        d.Year,
        COUNT(DISTINCT h.Receipt_Header_id) as Receipt_Count,
        DENSE_RANK() OVER (
            PARTITION BY d.Month_of_Year, d.Year 
            ORDER BY COUNT(DISTINCT h.Receipt_Header_id) DESC
        ) as Brand_Rank
    FROM dim_brands b
    JOIN fact_Receipt_line l ON b.Item_Id = l.Barcode
    JOIN fact_Receipt_Header h ON l.Receipt_Header_id = h.Receipt_Header_id
    JOIN dim_Date d ON h.Scanned_Date = d.Date
    JOIN recent_months rm ON d.Month_of_Year = rm.Month_of_Year 
                        AND d.Year = rm.Year
    WHERE rm.month_rank <= 2  -- Only include most recent and previous month
    GROUP BY b.Name, d.Month_of_Year, d.Year
)
SELECT 
    curr.Brand_Name,
    curr.Receipt_Count as Current_Month_Count,
    curr.Brand_Rank as Current_Month_Rank,
    prev.Receipt_Count as Previous_Month_Count,
    prev.Brand_Rank as Previous_Month_Rank,
    (prev.Brand_Rank - curr.Brand_Rank) as Rank_Change,
    ROUND(((curr.Receipt_Count - prev.Receipt_Count) / NULLIF(prev.Receipt_Count, 0) * 100), 2) as Count_Pct_Change
FROM brand_rankings curr
LEFT JOIN brand_rankings prev 
    ON curr.Brand_Name = prev.Brand_Name
    AND prev.Month_of_Year = (
        SELECT Month_of_Year 
        FROM recent_months 
        WHERE month_rank = 2
    )
    AND prev.Year = (
        SELECT Year 
        FROM recent_months 
        WHERE month_rank = 2
    )
WHERE curr.Month_of_Year = (
    SELECT Month_of_Year 
    FROM recent_months 
    WHERE month_rank = 1
)
AND curr.Year = (
    SELECT Year 
    FROM recent_months 
    WHERE month_rank = 1
)
AND (curr.Brand_Rank <= 5 OR prev.Brand_Rank <= 5)
ORDER BY curr.Brand_Rank;


#When considering average spend from receipts with 'rewardsReceiptStatus’ of ‘Accepted’ or ‘Rejected’, which is greater?
SELECT 
    Rewards_Receipt_Status,
    COUNT(Receipt_Header_id) as Receipt_Count,
    AVG(Total_Spent) as Average_Spend,
    SUM(Total_Spent) as Total_Spend
FROM fact_Receipt_Header
WHERE Rewards_Receipt_Status IN ('Accepted', 'Rejected')
GROUP BY Rewards_Receipt_Status
ORDER BY Average_Spend DESC;



#When considering total number of items purchased from receipts with 'rewardsReceiptStatus’ of ‘Accepted’ or ‘Rejected’, which is greater?
SELECT 
    h.Rewards_Receipt_Status,
    COUNT(DISTINCT h.Receipt_Header_id) as Receipt_Count,
    SUM(l.Quantity) as Total_Items_Purchased,
    ROUND(AVG(l.Quantity), 2) as Avg_Items_Per_Receipt
FROM fact_Receipt_Header h
JOIN fact_Receipt_line l ON h.Receipt_Header_id = l.Receipt_Header_id
WHERE h.Rewards_Receipt_Status IN ('Accepted', 'Rejected')
GROUP BY h.Rewards_Receipt_Status
ORDER BY Total_Items_Purchased DESC;



#Which brand has the most spend among users who were created within the past 6 months?
WITH recent_users AS (
    SELECT User_Id
    FROM dim_User
    WHERE Create_Date >= DATEADD(MONTH, -6, (SELECT MAX(Create_Date) FROM dim_User))
)
SELECT 
    b.Name as Brand_Name,
    COUNT(DISTINCT h.Receipt_Header_id) as Receipt_Count,
    COUNT(DISTINCT h.User_Id) as Unique_Users,
    SUM(l.Final_Price * l.Quantity) as Total_Spend,
    ROUND(AVG(l.Final_Price * l.Quantity), 2) as Avg_Spend_Per_Receipt
FROM dim_brands b
JOIN fact_Receipt_line l ON b.Item_Id = l.Barcode
JOIN fact_Receipt_Header h ON l.Receipt_Header_id = h.Receipt_Header_id
JOIN recent_users ru ON h.User_Id = ru.User_Id
GROUP BY b.Name
ORDER BY Total_Spend DESC
LIMIT 10;


#Which brand has the most transactions among users who were created within the past 6 months?
WITH recent_users AS (
    SELECT User_Id
    FROM dim_User
    WHERE Create_Date >= DATEADD(MONTH, -6, (SELECT MAX(Create_Date) FROM dim_User))
)
SELECT 
    b.Name as Brand_Name,
    COUNT(DISTINCT h.Receipt_Header_id) as Transaction_Count,
    COUNT(DISTINCT h.User_Id) as Unique_Users,
    SUM(l.Quantity) as Total_Items_Purchased,
    ROUND(AVG(l.Quantity), 2) as Avg_Items_Per_Transaction,
    ROUND(COUNT(DISTINCT h.Receipt_Header_id)::DECIMAL / COUNT(DISTINCT h.User_Id), 2) as Avg_Transactions_Per_User
FROM dim_brands b
JOIN fact_Receipt_line l ON b.Item_Id = l.Barcode
JOIN fact_Receipt_Header h ON l.Receipt_Header_id = h.Receipt_Header_id
JOIN recent_users ru ON h.User_Id = ru.User_Id
GROUP BY b.Name
ORDER BY Transaction_Count DESC
LIMIT 10;