-- =============================================================
-- LOCK TYPES
-- =============================================================
/*
Lock types:

1. Exclusive locks (X) - UPDATE, DELETE operations
2. Shared locks (S) - SELECT operations  
3. Update locks (U) - Prevent deadlocks during updates
4. Intent locks (I) - Hierarchical locking
5. Schema Locks - DDL operations
6. Bulk Update locks (BU) - BULK INSERT

Lock hierarchy (from smallest to largest):
Row → Page → Extent → Table → Database
*/

USE PerformanceLab;
GO

-- =============================================================
-- DEMO: Exclusive Lock (X)
-- =============================================================
PRINT '=== EXCLUSIVE LOCK DEMO ===';
GO

BEGIN TRANSACTION;
    PRINT 'Acquiring exclusive lock on CustomerID = 1';
    UPDATE Customers SET Email = 'exclusive_lock@test.com' WHERE CustomerID = 1;
    
    -- Check locks held by this session
    SELECT 
        resource_type,
        resource_description,
        request_mode,
        request_status
    FROM sys.dm_tran_locks
    WHERE request_session_id = @@SPID
        AND resource_type IN ('KEY', 'PAGE', 'OBJECT');
    
    PRINT 'Exclusive lock held. Other sessions CANNOT read or write this row.';
ROLLBACK;  -- only run this line to reverse locking
GO

-- =============================================================
-- DEMO: Shared Lock (S)
-- =============================================================
PRINT '=== SHARED LOCK DEMO ===';
GO

BEGIN TRANSACTION;
    PRINT 'Acquiring shared lock on CustomerID = 1';
    SELECT * FROM Customers WITH (HOLDLOCK) WHERE CustomerID = 1;
    -- HOLDLOCK keeps shared lock until transaction ends
    
    -- Check locks
    SELECT 
        resource_type,
        request_mode,
        request_status
    FROM sys.dm_tran_locks
    WHERE request_session_id = @@SPID
        AND resource_type IN ('KEY', 'PAGE', 'OBJECT');
    
    PRINT 'Shared lock held. Other sessions CAN read but CANNOT write.';
ROLLBACK; -- only run this line to reverse locking scenario
GO

-- =============================================================
-- DEMO: Update Lock (U)
-- =============================================================
PRINT '=== UPDATE LOCK DEMO ===';
GO

BEGIN TRANSACTION;
    PRINT 'Acquiring update lock during UPDATE';
    UPDATE Customers SET Email = 'update_lock@test.com' WHERE CustomerID = 1;
    
    -- Check locks
    SELECT 
        resource_type,
        request_mode,
        request_status
    FROM sys.dm_tran_locks
    WHERE request_session_id = @@SPID
        AND resource_type IN ('KEY', 'PAGE', 'OBJECT');
    
    -- You'll see: U lock converts to X lock during update
ROLLBACK;  -- only run this line to reverse locking scenario
GO