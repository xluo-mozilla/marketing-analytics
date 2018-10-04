-- Calculate install rate for mozilla.org funnel
-- Downloads from GA, installs from telemetry

WITH acqByDate AS(
SELECT
downloads.date,
downloads.downloads,
downloads.nonFXDownloads,
installs.installs,
installs.installs/downloads.nonFXDownloads as installRate
FROM(

-- Calculate downloads
(SELECT
  date as date,
  SUM(IF(downloads > 0,1,0)) as downloads,
  SUM(IF(downloads > 0 AND browser != 'Firefox',1,0)) as nonFXDownloads
FROM (SELECT
  date AS date,
  fullVisitorId as visitorId,
  visitNumber as visitNumber,
  trafficSource.source as source,
  device.browser as browser,
  SUM(IF (hits.eventInfo.eventAction = "Firefox Download",1,0)) as downloads
FROM
  `ga-mozilla-org-prod-001.65789850.ga_sessions_*`,
  UNNEST (hits) AS hits
WHERE
  _TABLE_SUFFIX >= '20170101'
  AND hits.type = 'EVENT'
  AND hits.eventInfo.eventCategory IS NOT NULL
  AND hits.eventInfo.eventLabel LIKE "Firefox for Desktop%"
GROUP BY
  1,2,3,4,5)
GROUP BY 1
ORDER BY 1) as downloads

LEFT JOIN
-- Calculate Installs
(SELECT
  submission_date_s3 AS date,
  SUM(installs) AS installs
FROM
  `ga-mozilla-org-prod-001.telemetry.corpMetrics`
WHERE funnelOrigin = 'mozFunnel'
GROUP BY 1
ORDER BY 1) as installs

ON downloads.date = installs.date))

SELECT * FROM acqByDate
ORDER BY 1