
-- =============================================================
-- BLOCKING - COMPREHENSIVE DETECTION
-- =============================================================
/*
"Blocking occurs when one user connection is holding a lock on an 
object or resource and at the same time another user connection 
tries to read or write on the same resource or objects."

Key points:
- A certain amount of blocking is normal and unavoidable
- If session "A" is waiting for resource "R" being used by session "B",
  session "B" is blocking session "A"
- Session "A" will wait but NOT be killed by SQL Server
*/

-- =============================================================
-- CREATE BLOCKING SCENARIO (3 Windows)
-- =============================================================

-- WINDOW 1: The blocker
USE PerformanceLab;
GO

PRINT '=== WINDOW 1: BLOCKER ===';
PRINT 'Session ID: ' + CAST(@@SPID AS VARCHAR(10));
GO

BEGIN TRANSACTION;
    -- Acquire exclusive lock
    UPDATE Customers SET Email = 'blocker@test.com' WHERE CustomerID BETWEEN 1 AND 100;
    PRINT 'Exclusive lock acquired on 100 customer rows';
    PRINT 'DO NOT COMMIT - leave transaction open!';
    PRINT '';
    
    -- Show locks held
    SELECT 
        'Locks held by this session:' AS Info,
        resource_type,
        resource_description,
        request_mode,
        request_status
    FROM sys.dm_tran_locks
    WHERE request_session_id = @@SPID
        AND resource_type IN ('KEY', 'PAGE', 'OBJECT', 'DATABASE')
    ORDER BY resource_type;
GO

-- STOP HERE - DO NOT COMMIT YET!

/*
When ready to release:
COMMIT;
-- or
ROLLBACK;
*/


-- WINDOW 2: The blocked session
USE PerformanceLab;
GO

PRINT '=== WINDOW 2: BLOCKED SESSION ===';
PRINT 'Session ID: ' + CAST(@@SPID AS VARCHAR(10));
PRINT 'Attempting to read locked rows...';
GO

-- This will BLOCK
SELECT * FROM Customers WHERE CustomerID BETWEEN 1 AND 100;

PRINT 'Query completed (after block released)';
GO


-- WINDOW 3: Blocking detection and resolution
USE master;
GO

PRINT '=== WINDOW 3: BLOCKING DETECTION ===';
PRINT '';
GO


-- =============================================================
-- Blocking chain (multi-level blocking) detection
-- =============================================================
;WITH BlockingChain AS (
    SELECT 
        session_id,
        blocking_session_id,
        wait_type,
        wait_time,
        wait_resource,
        1 AS Level
    FROM sys.dm_exec_requests
    WHERE blocking_session_id <> 0
    
    UNION ALL
    
    SELECT 
        r.session_id,
        r.blocking_session_id,
        r.wait_type,
        r.wait_time,
        r.wait_resource,
        bc.Level + 1
    FROM sys.dm_exec_requests r
    INNER JOIN BlockingChain bc ON r.session_id = bc.blocking_session_id
)
SELECT 
    Level,
    session_id AS SPID,
    blocking_session_id AS BlockedBy,
    wait_type AS WaitType,
    CAST(wait_time / 1000.0 AS DECIMAL(10,2)) AS WaitTime_Seconds
FROM BlockingChain
ORDER BY Level, session_id;
GO

-- =============================================================
-- RESOLUTION: Kill blocking session (use with caution!)
-- =============================================================
/*
Key point:
"Blockings can be killed – communicate with user for this will 
cause the current session to roll back"

To kill blocking session:
KILL <BlockingSPID>;

Example:
KILL 69; (in my case this was the blocking SPID)

WARNING: This rolls back the blocking transaction!
Only use if:
1. User is unresponsive
2. Blocking is causing production outage
3. You've communicated with user (if possible)
*/