-- =============================================================
-- DEADLOCK DEMONSTRATION
-- =============================================================
/*
Key point:
"Deadlock occurs when two sessions are waiting for a lock to clear 
on the other while holding it's own resources. This is a permanent 
blocking situation and would not be resolved by waiting."

"SQL server is capable to detect deadlocks and can declare one of 
the process as deadlock victim and kills that process."

Deadlock Priority:
- SQL Server chooses the LEAST EXPENSIVE transaction as victim
- "Transaction that makes the fewest changes to database is considered least expensive"
- Can override with SET DEADLOCK_PRIORITY (LOW, NORMAL, HIGH)
*/

-- =============================================================
-- STEP 1: Enable deadlock tracking
-- =============================================================
USE master;
GO

PRINT 'Enabling deadlock tracking (Trace Flag 1222)...';
DBCC TRACEON(1222, -1);
GO

-- =============================================================
-- STEP 2: Run deadlock scenario
-- =============================================================

-- WINDOW 1: Transaction 1
USE PerformanceLab;
GO

PRINT '=== TRANSACTION 1 ===';
PRINT 'Session ID: ' + CAST(@@SPID AS VARCHAR(10));
GO

BEGIN TRANSACTION;
    PRINT 'Step 1: Locking Customers table';
    UPDATE Customers SET FirstName = 'Deadlock1' WHERE CustomerID = 1;
    
    PRINT 'Step 2: Waiting 5 seconds...';
    WAITFOR DELAY '00:00:05';
    
    PRINT 'Step 3: Trying to lock Orders table (will deadlock!)';
    UPDATE Orders SET Status = 'Deadlock1' WHERE OrderID = 1;
    
    PRINT 'Transaction completed successfully';
COMMIT;
GO

-- WINDOW 2: Transaction 2 (run within 1-2 seconds of Window 1)
USE PerformanceLab;
GO

PRINT '=== TRANSACTION 2 ===';
PRINT 'Session ID: ' + CAST(@@SPID AS VARCHAR(10));
GO

BEGIN TRANSACTION;
    PRINT 'Step 1: Locking Orders table';
    UPDATE Orders SET Status = 'Deadlock2' WHERE OrderID = 1;
    
    PRINT 'Step 2: Waiting 5 seconds...';
    WAITFOR DELAY '00:00:05';
    
    PRINT 'Step 3: Trying to lock Customers table (will deadlock!)';
    UPDATE Customers SET FirstName = 'Deadlock2' WHERE CustomerID = 1;
    
    PRINT 'Transaction completed successfully';
COMMIT;
GO

-- =============================================================
-- Expected Result:
-- One session gets: Error 1205 - "deadlock victim"
-- Other session completes successfully
-- =============================================================

-- =============================================================
-- STEP 3: View deadlock graph
-- =============================================================
USE master;
GO

PRINT 'Viewing deadlock information from error log...';
EXEC sp_readerrorlog 0, 1, 'deadlock';
GO

-- Look for:
-- - Which sessions were involved (SPIDs)
-- - What resources they were waiting for
-- - Which session was chosen as victim
-- - Lock modes involved