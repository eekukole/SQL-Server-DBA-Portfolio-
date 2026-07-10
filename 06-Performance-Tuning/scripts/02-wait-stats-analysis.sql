-- =============================================================
-- WAIT TYPES - THE FOUNDATION OF PERFORMANCE TROUBLESHOOTING
-- =============================================================
/*
Key wait types:

CX_PACKET = Parallelism (multiple CPUs working on same query)
PAGEIOLATCH = Reading pages from disk (I/O bottleneck)
LCK_M_S = Shared lock wait (blocking on SELECT)
IO_COMPLETION = I/O subsystem latency
WRITELOG = Writing to transaction log (log disk slow)
RESOURCE_SEMAPHORE = Memory grant wait (not enough memory)

Quoteworthy:
"Wait Stats is a great way of finding performance issues and related 
queries that are causing resource consumption."
*/

USE master;
GO

-- =============================================================
-- STEP 1: Clear wait statistics to establish baseline
-- =============================================================
PRINT 'Clearing wait statistics for fresh baseline...';
DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);
GO

PRINT 'Baseline established at: ' + CONVERT(VARCHAR(20), GETDATE(), 120);
PRINT 'Run workload, then analyze wait stats after 10-15 minutes';
PRINT '';
GO

-- =============================================================
-- STEP 2: Comprehensive wait statistics query
-- =============================================================
-- (Based on sys.dm_os_wait_stats)

SELECT TOP 20
    wait_type AS WaitType,
    waiting_tasks_count AS WaitCount,
    CAST(wait_time_ms / 1000.0 AS DECIMAL(12,2)) AS WaitTime_Seconds,
    CAST(max_wait_time_ms / 1000.0 AS DECIMAL(12,2)) AS MaxWait_Seconds,
    CAST(wait_time_ms / NULLIF(waiting_tasks_count, 0) AS DECIMAL(12,2)) AS AvgWait_MS,
    CAST((wait_time_ms * 100.0 / SUM(wait_time_ms) OVER()) AS DECIMAL(5,2)) AS PercentOfTotal,
    
    -- Categorize wait type
    CASE 
        WHEN wait_type LIKE 'PAGEIOLATCH%' THEN 'I/O - Disk Read/Write'
        WHEN wait_type LIKE 'WRITELOG%' THEN 'I/O - Transaction Log'
        WHEN wait_type LIKE 'LCK_%' THEN 'Blocking - Lock Wait'
        WHEN wait_type = 'CXPACKET' THEN 'Parallelism'
        WHEN wait_type LIKE 'RESOURCE_SEMAPHORE%' THEN 'Memory Pressure'
        WHEN wait_type LIKE 'SOS_SCHEDULER_YIELD%' THEN 'CPU Pressure'
        WHEN wait_type LIKE 'IO_COMPLETION%' THEN 'I/O - General'
        WHEN wait_type LIKE 'ASYNC_NETWORK_IO%' THEN 'Network - Client Slow'
        ELSE 'Other'
    END AS WaitCategory,
    
    -- Recommended action
    CASE 
        WHEN wait_type LIKE 'PAGEIOLATCH%' THEN 'Check disk I/O, add indexes, increase memory'
        WHEN wait_type LIKE 'WRITELOG%' THEN 'Faster log disk, smaller transactions'
        WHEN wait_type LIKE 'LCK_%' THEN 'Investigate blocking, reduce transaction time'
        WHEN wait_type = 'CXPACKET' THEN 'Review parallelism settings, check for skew'
        WHEN wait_type LIKE 'RESOURCE_SEMAPHORE%' THEN 'Add memory, optimize queries'
        WHEN wait_type LIKE 'SOS_SCHEDULER_YIELD%' THEN 'Add CPU, optimize queries'
        ELSE 'Review specific wait type documentation'
    END AS RecommendedAction
    
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
    -- Filter benign waits
    'BROKER_EVENTHANDLER', 'BROKER_RECEIVE_WAITFOR', 'BROKER_TASK_STOP',
    'BROKER_TO_FLUSH', 'BROKER_TRANSMITTER', 'CHECKPOINT_QUEUE',
    'CHKPT', 'CLR_AUTO_EVENT', 'CLR_MANUAL_EVENT', 'CLR_SEMAPHORE',
    'DBMIRROR_DBM_EVENT', 'DBMIRROR_EVENTS_QUEUE', 'DBMIRROR_WORKER_QUEUE',
    'DBMIRRORING_CMD', 'DIRTY_PAGE_POLL', 'DISPATCHER_QUEUE_SEMAPHORE',
    'EXECSYNC', 'FSAGENT', 'FT_IFTS_SCHEDULER_IDLE_WAIT', 'FT_IFTSHC_MUTEX',
    'HADR_CLUSAPI_CALL', 'HADR_FILESTREAM_IOMGR_IOCOMPLETION', 'HADR_LOGCAPTURE_WAIT',
    'HADR_NOTIFICATION_DEQUEUE', 'HADR_TIMER_TASK', 'HADR_WORK_QUEUE',
    'LAZYWRITER_SLEEP', 'LOGMGR_QUEUE', 'MEMORY_ALLOCATION_EXT',
    'ONDEMAND_TASK_QUEUE', 'PARALLEL_REDO_WORKER_WAIT_WORK',
    'PREEMPTIVE_XE_GETTARGETSTATE', 'PWAIT_ALL_COMPONENTS_INITIALIZED',
    'PWAIT_DIRECTLOGCONSUMER_GETNEXT', 'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
    'QDS_ASYNC_QUEUE', 'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
    'QDS_SHUTDOWN_QUEUE', 'REDO_THREAD_PENDING_WORK', 'REQUEST_FOR_DEADLOCK_SEARCH',
    'RESOURCE_QUEUE', 'SERVER_IDLE_CHECK', 'SLEEP_BPOOL_FLUSH', 'SLEEP_DBSTARTUP',
    'SLEEP_DCOMSTARTUP', 'SLEEP_MASTERDBREADY', 'SLEEP_MASTERMDREADY',
    'SLEEP_MASTERUPGRADED', 'SLEEP_MSDBSTARTUP', 'SLEEP_SYSTEMTASK', 'SLEEP_TASK',
    'SLEEP_TEMPDBSTARTUP', 'SNI_HTTP_ACCEPT', 'SP_SERVER_DIAGNOSTICS_SLEEP',
    'SQLTRACE_BUFFER_FLUSH', 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
    'SQLTRACE_WAIT_ENTRIES', 'WAIT_FOR_RESULTS', 'WAITFOR', 'WAITFOR_TASKSHUTDOWN',
    'WAIT_XTP_RECOVERY', 'WAIT_XTP_HOST_WAIT', 'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
    'WAIT_XTP_CKPT_CLOSE', 'XE_DISPATCHER_JOIN', 'XE_DISPATCHER_WAIT',
    'XE_TIMER_EVENT'
)
AND waiting_tasks_count > 0
ORDER BY wait_time_ms DESC;
GO

-- =============================================================
-- MY TOP 5 WAIT TYPES
-- =============================================================
/*
1. SOS_WORK_DISPATCHER
Total Wait: 49684.62 seconds
Count: 1,096,633 waits
Avg Wait: 45.00 ms
Meaning: Other
Action: Review specific wait type documentation

2. PREEMPTIVE_XE_CALLBACKEXECUTE
Total Wait: 0.50 seconds
Count: 125,314 waits
Avg Wait: 0.00 ms
Meaning: Other
Action: Review specific wait type documentation

3. PAGEIOLATCH_SH
Total Wait: 0.37 seconds
Count: 842 waits
Avg Wait: 0.00 ms
Meaning: I/O - Disk Read/Write
Action: Check disk I/O, add indexes, increase memory

4. THREADPOOL
Total Wait: 0.25 seconds
Count: 284 waits
Avg Wait: 0.00 ms
Meaning: Other
Action: Review specific wait type documentation

5. ASYNC_NETWORK_IO
Total Wait: 0.15 seconds
Count: 2162 waits
Avg Wait: 0.00 ms
Meaning: Network - Client Slow
Action: Review specific wait type documentation
*/



-- =============================================================
-- WAIT TYPE DIAGNOSTIC SCENARIOS
-- =============================================================
/*
SCENARIO 1: Signal Wait Percent
Study note: "Percentage of time sessions are in a runnable queue waiting for a CPU to become available"

If Signal Wait % is HIGH (>15-20%):
- Wait Type: SOS_SCHEDULER_YIELD
- Problem: CPU bottleneck
- Solution: Add CPU, optimize queries, reduce sessions

SCENARIO 2: Page I/O Latch
Study note: "They indicate a task is waiting to access a data page that is 
not in the buffer pool, so it must be read from disk to memory"

High PAGEIOLATCH waits indicate:
- Problem: Disk I/O bottleneck
- Solutions (from your slide):
  * Tune stored procedure to read fewer pages
  * Enable Lock Pages in Memory (LPIM)
  * Add memory
  * Redistribute database files to multiple I/O channels
  * Tune queries so fewer pages are read

SCENARIO 3: WRITELOG
Study note: "The disk that stores the transaction log is performing poorly"

Solutions:
- Use fast storage for transaction logs
- Disable unused indexes (reduce log writes)

SCENARIO 4: CXPACKET
Study note: "Directly related to parallelism - exchange of data rows among 
parallel threads"

If CXPACKET < 50% of total waits = not a problem (just parallelism working)
If CXPACKET > 50% = potential issue

Solutions:
- Increase CTP (Cost Threshold for Parallelism)
- Identify what's causing uneven distribution (improper indexing, obsolete stats)
*/

-- =============================================================
-- PRACTICAL EXERCISE: Creating scenarios that generate each wait type
-- =============================================================

USE PerformanceLab;
GO

-- Generate PAGEIOLATCH waits (disk I/O)
PRINT 'Generating PAGEIOLATCH waits...';
DBCC DROPCLEANBUFFERS;  -- Clear buffer cache
GO

SELECT COUNT(*) FROM Customers;  -- Forces disk reads
GO

-- Check wait stats immediately
SELECT wait_type, waiting_tasks_count, wait_time_ms
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'PAGEIOLATCH%'
ORDER BY wait_time_ms DESC;
GO

/* My Results:
1. PAGEIOLATCH_SH
   Waiting: 971 tasks
   Wait time: 444 ms

2. PAGEIOLATCH_EX
   Waiting: 25 tasks
   Wait time: 10 ms
*/

-- Generate WRITELOG waits (transaction log writes)
PRINT 'Generating WRITELOG waits...';
BEGIN TRANSACTION;
    UPDATE Customers SET Email = 'writelog_test@email.com' WHERE CustomerID < 1000;
    -- Large update generates log writes
ROLLBACK;
GO

-- Check WRITELOG waits
SELECT wait_type, waiting_tasks_count, wait_time_ms
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'WRITELOG%';
GO

/* My Results:
WRITELOG
 Waiting: 32 tasks
 Wait time: 17 ms
*/

-- Generate CXPACKET waits (parallelism)
PRINT 'Generating CXPACKET waits...';
SELECT c.*, o.*
FROM Customers c
CROSS JOIN Orders o
WHERE c.CustomerID < 5000;  -- Large query that uses parallelism
GO

-- Check CXPACKET waits
SELECT wait_type, waiting_tasks_count, wait_time_ms
FROM sys.dm_os_wait_stats
WHERE wait_type = 'CXPACKET';
GO