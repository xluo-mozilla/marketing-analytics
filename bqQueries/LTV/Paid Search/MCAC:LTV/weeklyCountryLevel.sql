 --Pulls together data from Fetch, GA, Corpmetrics and Telemetry to tell the story of Spend, downloads, installs, LTV
WITH
  --Data pull from telemetry.corpmetrics as the root for our data system. Data from other systems will be joined to this.
  telCorp AS (
  SELECT
    submission_date_s3,
    REPLACE(REPLACE(REPLACE(REPLACE(contentCleaned,'%2528','('),'%2529',')'),'%2B',' '),'%257C','|') t_content,
    SUM(installs) AS sum_installs,
    SUM(dau) AS sum_dau
  FROM
    `telemetry.corpMetrics`
  GROUP BY
    1,
    2 ),
  --Joins with LTV data set based on source, medium, campaign, and content
  l AS (
  SELECT
    f.country,
    f.targeting,
    CASE
      WHEN REGEXP_EXTRACT(socialstring, r'(.*)_') LIKE '%Competitor%' THEN 'Competitor'
      WHEN REGEXP_EXTRACT(socialstring, r'(.*)_') LIKE '%Browser%' THEN 'Browser'
    END AS AGroup,
    COUNT(DISTINCT(client_ID)) n,
    AVG(total_clv) avg_tLTV
  FROM
    `ltv.ltv_v1`
  LEFT JOIN
    `fetch.fetch_deduped` AS f
  ON
    content = f.adname
  WHERE
    historical_searches < (
    SELECT
      STDDEV(historical_searches)
    FROM
      `ltv.ltv_v1`) *5 + (
    SELECT
      AVG(historical_searches)
    FROM
      `ltv.ltv_v1`)
    AND vendor IN ('Adwords',
      'Bing')
    AND f.country IN ('United States',
      'Canada',
      'Germany')
    AND targeting = 'Nonbrand Search'
    AND vendornetspend >0
  GROUP BY
    1,
    2,
    3
  ORDER BY
    1,
    2,
    3 DESC),
  --Pulls VendorNetSpend by ad and day from FetchMme
  f AS (
  SELECT
    --turns date into a string and removes '-'
    *
  FROM
    `fetch.fetch_deduped`)
  --Pulls whole table
SELECT
  country,
  targeting,
  week_num,

sum_vendornetspend,
  sum_fetchdownloads,
  proj_installs,
  CPD,
  proj_cpi,
  n,
  avg_tLTV,
  avg_tLTV * proj_installs AS revenue,
  (avg_tLTV * proj_installs) - sum_vendornetspend AS profit,
  (avg_tLTV * proj_installs)/sum_vendornetspend AS mcac_ltv
FROM (
  SELECT
    DATE_DIFF(Date,DATE(2018,01,03),week) as week_num,
    Country,
    targeting,
    
    SUM(vendorNetSpend) sum_vendornetspend,
    --  sum(downloads) sum_downloads,
    SUM(downloadsGA) sum_fetchdownloads,
    SUM(downloadsGA)*.66 proj_installs,
    SUM(vendornetspend)/SUM(downloadsGA) AS CPD,
    SUM(vendornetspend)/(SUM(downloadsGA)*.66) AS proj_CPI
  FROM
    --Fetch is the base table
    f
  LEFT JOIN
    telcorp
  ON
    REPLACE(CAST(date AS STRING),'-','') = telcorp.submission_date_s3
    AND f.adname = telcorp.t_content
  WHERE
    vendor IN ('Adwords',
      'Bing')
    AND country IN ('United States',
      'Canada',
      'Germany')
    AND REPLACE(CAST(f.date AS STRING),'-','') BETWEEN '20180701'
    AND '20180831'
    AND targeting = 'Nonbrand Search'
    AND vendornetspend >0
  GROUP BY
    1,
    2,3
  ORDER BY
    1,
    2,
    3 DESC) AS Qa
LEFT JOIN (
  SELECT
    f.country AS b_country,
    f.targeting AS b_targeting,
    COUNT(DISTINCT(client_ID)) n,
    AVG(total_clv) avg_tLTV
  FROM
    `ltv.ltv_v1`
  LEFT JOIN
    `fetch.fetch_deduped` AS f
  ON
    content = f.adname
  WHERE
    historical_searches < (
    SELECT
      STDDEV(historical_searches)
    FROM
      `ltv.ltv_v1`) *5 + (
    SELECT
      AVG(historical_searches)
    FROM
      `ltv.ltv_v1`)
    AND vendor IN ('Adwords',
      'Bing')
    AND f.country IN ('United States',
      'Canada',
      'Germany')
    AND targeting = 'Nonbrand Search'
    AND vendornetspend >0
  GROUP BY
    1,
    2 ) AS Qb
ON
  Qa.country = Qb.b_country
  AND QA.targeting =Qb.b_targeting
ORDER BY
  1,
  2,
  3 ASC