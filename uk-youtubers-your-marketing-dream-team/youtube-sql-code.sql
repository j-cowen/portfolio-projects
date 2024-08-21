-- Select the relevant columns.
-- Rename first column with appropriate alias (not necessary for all other columns).
-- Remove the YouTube handle from column_name, so that only the YouTube channel name remains.

SELECT
    SUBSTRING(NOMBRE, 1, CHARINDEX('@', NOMBRE) - 1) AS channel_name,
    total_subscribers,
    total_views,
    total_videos
FROM top_uk_youtubers_2024

-- Create a SQL view to store the transformed data

CREATE VIEW view_top_uk_youtubers_2024
AS
SELECT
    SUBSTRING(NOMBRE, 1, CHARINDEX('@', NOMBRE) - 1) AS channel_name,
    total_subscribers,
    total_views,
    total_videos
FROM top_uk_youtubers_2024


-- There should only be 100 rows, representing the top 100 UK YouTubers in 2024.

SELECT COUNT(*)
FROM view_top_uk_youtubers_2024


-- There should only be 4 columns.

SELECT COUNT(*) AS column_count
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'view_top_uk_youtubers_2024'


-- Review table structure.

SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'view_top_uk_youtubers_2024'


-- There should not be any duplicate channel_name

SELECT channel_name, COUNT(*)
FROM view_top_uk_youtubers_2024
GROUP BY channel_name
HAVING COUNT(*) > 1


-- DAX Measures

-- Total Views (B)
Total Views (B) = 
VAR billion = 1000000000
VAR sumOfViews = SUM(view_top_uk_youtubers_2024[total_views])
VAR totalViews = DIVIDE(sumOfViews,billion)

RETURN totalViews

-- Total Videos
Total Videos = 
VAR totalVideos = SUM(view_top_uk_youtubers_2024[total_videos])

RETURN totalVideos

-- Total Subscribers (M)
Total Subscribers (M) = 
VAR million = 1000000
VAR sumOfSubscribers = SUM(view_top_uk_youtubers_2024[total_subscribers])
VAR totalSubscribers = DIVIDE(sumOfSubscribers,million)

RETURN totalSubscribers

-- Avg Views per Video (M)
Avg Views per Video (M) = 

VAR million = 1000000
VAR sumOfTotalViews = SUM(view_top_uk_youtubers_2024[total_views])
VAR sumOfTotalVideos = SUM(view_top_uk_youtubers_2024[total_videos])
VAR avgOfViewsPerVideo = DIVIDE(sumOfTotalViews,sumOfTotalVideos,BLANK())
VAR finalAvgViewsPerVideo = DIVIDE(avgOfViewsPerVideo, million, BLANK())

RETURN finalAvgViewsPerVideo

-- Subscriber Engagement Rate
Subscriber Engagement Rate = 

VAR sumOfTotalSubscribers = SUM(view_top_uk_youtubers_2024[total_subscribers])
VAR sumOfTotalVideos = SUM(view_top_uk_youtubers_2024[total_videos])
VAR subscriberEngagementRate = DIVIDE(sumOfTotalSubscribers, sumOfTotalVideos, BLANK())

RETURN subscriberEngagementRate

-- Views per Subscriber
Views per Subscriber = 

VAR sumOfTotalViews = SUM(view_top_uk_youtubers_2024[total_views])
VAR sumOfTotalSubscribers = SUM(view_top_uk_youtubers_2024[total_subscribers])
VAR viewsPerSubscriber = DIVIDE(sumOfTotalViews, sumOfTotalSubscribers, BLANK())

RETURN viewsPerSubscriber


--Total Subscriber Analysis

DECLARE @conversionRate FLOAT = 0.02;     -- The conversion rate at 2%

DECLARE @productCost MONEY = 5.0;         -- The product cost at $5

DECLARE @campaignCost MONEY = 50000.0;    -- The campaign cost at $50,000

WITH ChannelData AS
    (
    SELECT 
        channel_name,
        total_views, 
        total_videos,
		total_subscribers,
         ROUND(CAST(total_views AS FLOAT) / total_videos, -4) AS rounded_avg_views_per_video,
         ROUND(CAST(total_views AS FLOAT) / total_videos, -4) * @conversionRate AS potential_product_sales,
         ROUND(CAST(total_views AS FLOAT) / total_videos, -4) * @conversionRate*@productCost AS potential_revenue_per_video,
        (ROUND(CAST(total_views AS FLOAT) / total_videos, -4) * @conversionRate*@productCost) - @campaignCost AS net_profit
    FROM view_top_uk_youtubers_2024
    )

SELECT 
	TOP(3) 
	channel_name,
	rounded_avg_views_per_video,
	potential_product_sales,
	potential_revenue_per_video,
	net_profit
FROM ChannelData
ORDER BY total_subscribers DESC


--Total Videos Analysis

DECLARE @conversionRate FLOAT = 0.02;           -- The conversion rate at 2%

DECLARE @productCost FLOAT = 5.0;               -- The product cost at $5

DECLARE @campaignCostPerVideo FLOAT = 5000.0;   -- The campaign cost per video at $5,000

DECLARE @numberOfVideos INT = 11;               -- The number of videos (11)

WITH ChannelData AS 
    (
    SELECT
        channel_name,
        total_views,
        total_videos,
        ROUND((CAST(total_views AS FLOAT) / total_videos), -4) AS rounded_avg_views_per_video
    FROM view_top_uk_youtubers_2024
    )

SELECT
    channel_name,
    rounded_avg_views_per_video,
    (rounded_avg_views_per_video * @conversionRate) AS potential_units_sold_per_video,
    (rounded_avg_views_per_video * @conversionRate * @productCost) AS potential_revenue_per_video,
    ((rounded_avg_views_per_video * @conversionRate * @productCost) - (@campaignCostPerVideo * @numberOfVideos)) AS net_profit
FROM ChannelData
WHERE channel_name IN ('GRM Daily', 'Man City', 'YOGSCAST Lewis & Simon ')
ORDER BY net_profit DESC

