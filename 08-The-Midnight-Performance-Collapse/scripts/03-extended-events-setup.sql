-- =============================================================
-- EXTENDED EVENT: Capture queries > 1 second
-- =============================================================
/*
Key point:
"Extended Events allows DBAs to monitor what's going on in a SQL Server instance.
Replaces SQL Profiler, Extended events has much less overhead."

Benefits:
- Built into SSMS
- Sessions can be created without any T-SQL commands
- Hardly any overhead when using them on SQL Server
- Less than 2% of the CPU resource
- Easy to use and powerful (Wizard Driven)
*/

USE master;
GO

-- Check if session already exists
IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'CaptureSlowQueries')
    DROP EVENT SESSION CaptureSlowQueries ON SERVER;
GO

-- Create Extended Event session
CREATE EVENT SESSION CaptureSlowQueries ON SERVER
ADD EVENT sqlserver.rpc_completed (
    ACTION (
        sqlserver.client_app_name,
        sqlserver.client_hostname,
        sqlserver.database_name,
        sqlserver.session_id,
        sqlserver.sql_text,
        sqlserver.username
    )
    WHERE (
        duration >= 1000000  -- 1 second (duration in microseconds)
        AND database_name = N'MedicalRecords_PROD'
    )
),
ADD EVENT sqlserver.sql_batch_completed (
    ACTION (
        sqlserver.client_app_name,
        sqlserver.database_name,
        sqlserver.session_id,
        sqlserver.sql_text,
        sqlserver.username
    )
    WHERE (
        duration >= 1000000  -- 1 second
        AND database_name = N'MedicalRecords_PROD'
    )
)
ADD TARGET package0.event_file (
    SET filename = N'L:\JIT-PRD-SQL1-EE\SlowQueries.xel',  -- set your own path here
        max_file_size = 50,  -- 50 MB per file
        max_rollover_files = 5  -- Keep 5 files (250 MB total)
);
GO

-- Start the session
ALTER EVENT SESSION CaptureSlowQueries ON SERVER
STATE = START;
GO

PRINT 'Extended Event session "CaptureSlowQueries" created and started';
PRINT 'Capturing queries > 1 second in MedicalRecords_PROD';
PRINT 'Target file: L:\JIT-PRD-SQL1-EE\SlowQueries.xel'; -- set your own path here
GO



-- =============================================================
-- EXTENDED EVENT: Capture Deadlocks
-- =============================================================
/*
Key point:
"The most remarkable advantage you may enjoy is that the default 
system Extended Events session that is already passively running 
on SQL Server 2012 and later, captures deadlocks. This means that for the 
first time, you can diagnose a deadlock that happened in the past 
without setting up and catching a SQL Trace."
*/

USE master;
GO

IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'CaptureDeadlocks')
    DROP EVENT SESSION CaptureDeadlocks ON SERVER;
GO

CREATE EVENT SESSION CaptureDeadlocks ON SERVER
ADD EVENT sqlserver.xml_deadlock_report (
    ACTION (
        sqlserver.client_app_name,
        sqlserver.database_name,
        sqlserver.session_id,
        sqlserver.username
    )
)
ADD TARGET package0.event_file (
    SET filename = N'L:\JIT-PRD-SQL1-EE\Deadlocks.xel',  -- set your own file path here
        max_file_size = 10,
        max_rollover_files = 10
);
GO

ALTER EVENT SESSION CaptureDeadlocks ON SERVER
STATE = START;
GO

PRINT 'Extended Event session "CaptureDeadlocks" created and started';
GO





-- =============================================================
-- EXTENDED EVENT: Capture Blocking > 5 seconds
-- =============================================================

USE master;
GO

IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'CaptureBlocking')
    DROP EVENT SESSION CaptureBlocking ON SERVER;
GO

CREATE EVENT SESSION CaptureBlocking ON SERVER
ADD EVENT sqlserver.blocked_process_report (
    ACTION (
        sqlserver.client_app_name,
        sqlserver.database_name,
        sqlserver.session_id,
        sqlserver.sql_text,
        sqlserver.username
    )
)
ADD TARGET package0.event_file (
    SET filename = N'C:\SQLLogs\Blocking.xel',
        max_file_size = 25,
        max_rollover_files = 5
);
GO

-- Enable blocked process threshold (5 seconds)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

EXEC sp_configure 'blocked process threshold', 5;  -- Report after 5 seconds
RECONFIGURE;
GO

ALTER EVENT SESSION CaptureBlocking ON SERVER
STATE = START;
GO

PRINT 'Extended Event session "CaptureBlocking" created and started';
PRINT 'Will capture blocking > 5 seconds';
GO






-- =============================================================
-- ANALYZE: Read Extended Event Files
-- =============================================================

-- Query slow queries captured
SELECT 
    event_data.value('(event/@name)[1]', 'varchar(50)') AS EventName,
    event_data.value('(event/@timestamp)[1]', 'datetime') AS EventTime,
    event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint') / 1000 AS Duration_MS,
    event_data.value('(event/action[@name="sql_text"]/value)[1]', 'varchar(max)') AS SQLText,
    event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(100)') AS DatabaseName,
    event_data.value('(event/action[@name="username"]/value)[1]', 'varchar(100)') AS Username,
    event_data.value('(event/action[@name="session_id"]/value)[1]', 'int') AS SessionID
FROM (
    SELECT CAST(event_data AS XML) AS event_data
    FROM sys.fn_xe_file_target_read_file('C:\SQLLogs\SlowQueries*.xel', NULL, NULL, NULL)
) AS XEventData
ORDER BY Duration_MS DESC;
GO

-- Query deadlock graphs
SELECT 
    event_data.value('(event/@timestamp)[1]', 'datetime') AS DeadlockTime,
    event_data.value('(event/data[@name="xml_report"]/value)[1]', 'xml') AS DeadlockGraph
FROM (
    SELECT CAST(event_data AS XML) AS event_data
    FROM sys.fn_xe_file_target_read_file('C:\SQLLogs\Deadlocks*.xel', NULL, NULL, NULL)
) AS XEventData
ORDER BY DeadlockTime DESC;
GO

-- Query blocking events
SELECT 
    event_data.value('(event/@timestamp)[1]', 'datetime') AS BlockingTime,
    event_data.value('(event/data[@name="blocked_process"]/value/blocked-process-report)[1]', 'xml') AS BlockingReport
FROM (
    SELECT CAST(event_data AS XML) AS event_data
    FROM sys.fn_xe_file_target_read_file('C:\SQLLogs\Blocking*.xel', NULL, NULL, NULL)
) AS XEventData
ORDER BY BlockingTime DESC;
GO