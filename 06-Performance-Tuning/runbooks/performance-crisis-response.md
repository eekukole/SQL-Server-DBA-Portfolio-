\# Performance Crisis Response - Step-by-Step Runbook



\## 🚨 SCENARIO: "The database is slow!"



Follow these steps in order. Don't skip steps.



\---



\## STEP 1: Identify the Problem Type (2 minutes)



Run this quick diagnostic:



```sql

\-- Quick health check

SELECT 

&#x20;   'CPU Pressure' AS Issue,

&#x20;   CASE WHEN AVG(signal\_wait\_time\_ms \* 100.0 / wait\_time\_ms) > 15 

&#x20;        THEN '🔴 YES' ELSE '✅ NO' END AS Status

FROM sys.dm\_os\_wait\_stats

WHERE wait\_time\_ms > 0

UNION ALL

SELECT 

&#x20;   'Blocking',

&#x20;   CASE WHEN COUNT(\*) > 0 THEN '🔴 YES' ELSE '✅ NO' END

FROM sys.dm\_exec\_requests WHERE blocking\_session\_id <> 0

UNION ALL

SELECT 

&#x20;   'Disk I/O',

&#x20;   CASE WHEN SUM(io\_stall) / NULLIF(SUM(num\_of\_reads + num\_of\_writes), 0) > 20

&#x20;        THEN '🔴 YES' ELSE '✅ NO' END

FROM sys.dm\_io\_virtual\_file\_stats(NULL, NULL);

```



\*\*Result tells you where to jump:\*\*

\- CPU Pressure → Go to STEP 2A

\- Blocking → Go to STEP 2B

\- Disk I/O → Go to STEP 2C



\---



\## STEP 2A: CPU Pressure Response



\*\*Symptom:\*\* Signal Wait% > 15%, SOS\_SCHEDULER\_YIELD waits high



\*\*Immediate Actions:\*\*

1\. Find top CPU consuming queries:

```sql

SELECT TOP 5

&#x20;   CAST(total\_worker\_time / 1000000.0 AS DECIMAL(10,2)) AS CPU\_Seconds,

&#x20;   execution\_count,

&#x20;   SUBSTRING(text, 1, 200) AS QueryText

FROM sys.dm\_exec\_query\_stats

CROSS APPLY sys.dm\_exec\_sql\_text(sql\_handle)

ORDER BY total\_worker\_time DESC;

```



2\. For each expensive query:

&#x20;  - Check execution plan (look for scans, missing indexes)

&#x20;  - Check if parallelism is excessive (CXPACKET waits)

&#x20;  - Consider killing if non-essential



\*\*Short-term Fix:\*\*

\- Kill expensive non-essential queries

\- Reduce max degree of parallelism temporarily



\*\*Long-term Fix:\*\*

\- Optimize queries

\- Add indexes

\- Consider hardware upgrade



\---



\## STEP 2B: Blocking Response



\*\*Symptom:\*\* LCK\_M\_\* waits high, blocking\_session\_id <> 0



\*\*Immediate Actions:\*\*

1\. Identify blocking chain:

```sql

SELECT 

&#x20;   blocked.session\_id AS Blocked,

&#x20;   blocked.blocking\_session\_id AS Blocker,

&#x20;   CAST(blocked.wait\_time / 1000.0 AS DECIMAL(10,2)) AS Wait\_Seconds,

&#x20;   blocked\_sql.text AS BlockedQuery,

&#x20;   blocker\_sql.text AS BlockingQuery,

&#x20;   'KILL ' + CAST(blocked.blocking\_session\_id AS VARCHAR(10)) + ';' AS KillCommand

FROM sys.dm\_exec\_requests blocked

INNER JOIN sys.dm\_exec\_sessions blocker ON blocked.blocking\_session\_id = blocker.session\_id

CROSS APPLY sys.dm\_exec\_sql\_text(blocked.sql\_handle) blocked\_sql

CROSS APPLY sys.dm\_exec\_sql\_text(blocker.most\_recent\_sql\_handle) blocker\_sql

WHERE blocked.blocking\_session\_id <> 0;

```



2\. Decision tree:

&#x20;  - If blocking < 30 seconds → Monitor, may resolve naturally

&#x20;  - If blocking > 30 seconds → Contact blocking user

&#x20;  - If blocking > 5 minutes OR production outage → KILL session



\*\*To kill:\*\*

```sql

KILL <SessionID>;

```



\*\*Communication template:\*\*

"Hi \[User], your session (SPID XX) is blocking critical queries. We need to end your session to restore service. Your transaction will be rolled back. Please reconnect and resubmit."



\---



\## STEP 2C: Disk I/O Response



\*\*Symptom:\*\* PAGEIOLATCH waits high, io\_stall > 20ms



\*\*Immediate Actions:\*\*

1\. Check which files are slow:

```sql

SELECT TOP 5

&#x20;   DB\_NAME(database\_id) AS DBName,

&#x20;   file\_id,

&#x20;   io\_stall / (num\_of\_reads + num\_of\_writes) AS AvgStall\_MS,

&#x20;   num\_of\_reads + num\_of\_writes AS Total\_IOs,

&#x20;   CAST(num\_of\_bytes\_read / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS MB\_Read

FROM sys.dm\_io\_virtual\_file\_stats(NULL, NULL)

WHERE num\_of\_reads + num\_of\_writes > 0

ORDER BY io\_stall DESC;

```



2\. Find I/O intensive queries:

```sql

SELECT TOP 5

&#x20;   total\_logical\_reads,

&#x20;   execution\_count,

&#x20;   total\_logical\_reads / execution\_count AS Avg\_Reads,

&#x20;   SUBSTRING(text, 1, 200) AS QueryText

FROM sys.dm\_exec\_query\_stats

CROSS APPLY sys.dm\_exec\_sql\_text(sql\_handle)

ORDER BY total\_logical\_reads DESC;

```



\*\*Short-term Fix:\*\*

\- Add missing indexes (check sys.dm\_db\_missing\_index\_details)

\- Increase memory (more data cached = less disk reads)

\- Kill I/O intensive non-essential queries



\*\*Long-term Fix:\*\*

\- Optimize queries to read fewer pages

\- Faster storage (SSDs)

\- Separate data and log files to different disks



\---



\## STEP 3: Monitor and Document (Ongoing)



\*\*Every 5 minutes, capture:\*\*

```sql

INSERT INTO PerformanceLog (CaptureTime, TopWaitType, BlockedSessions, AvgCPU)

SELECT 

&#x20;   GETDATE(),

&#x20;   (SELECT TOP 1 wait\_type FROM sys.dm\_os\_wait\_stats ORDER BY wait\_time\_ms DESC),

&#x20;   (SELECT COUNT(\*) FROM sys.dm\_exec\_requests WHERE blocking\_session\_id <> 0),

&#x20;   (SELECT AVG(cpu\_time) FROM sys.dm\_exec\_requests);

```



\*\*After resolution:\*\*

\- Document what happened

\- Root cause analysis

\- Preventive measures

\- Update monitoring alerts



\---



\## STEP 4: Post-Incident Review



\*\*Questions to answer:\*\*

1\. What was the root cause?

2\. How long did it last?

3\. What was the business impact?

4\. What immediate action was taken?

5\. What prevented early detection?

6\. What permanent fix is needed?



\*\*Deliver to stakeholders:\*\*

\- Timeline of events

\- Actions taken

\- Long-term remediation plan

\- Updated monitoring thresholds

