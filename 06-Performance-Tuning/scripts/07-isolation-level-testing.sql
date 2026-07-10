-- =============================================================
-- ISOLATION LEVELS
-- =============================================================
/*
4 isolation levels (from highest to lowest):

1. SERIALIZABLE (Highest)
   - One transaction must complete before another can start
   - No dirty reads, no phantom reads
   - Most restrictive

2. REPEATABLE READS
   - Data can be accessed once transaction has started, even if not finished
   - Allows phantom reads (new rows inserted)
   - No dirty reads

3. READ COMMITTED (Default in SQL Server)
   - Data can be accessed after committed to database, but not before
   - No dirty reads
   - Allows non-repeatable reads

4. READ UNCOMMITTED (Lowest)
   - Lowest level of isolation
   - Allows data to be accessed before changes have been made
   - Allows dirty reads (reading uncommitted data)

Key point:
"As the isolation level is lowered, the more there is a chance that 
users will encounter read phenomena such as uncommitted dependencies, 
also known as dirty reads, which result in data being read from a 
row that has been modified by another user but not yet committed to 
the database."
*/

USE PerformanceLab;
GO

-- =============================================================
-- DEMO 1: READ UNCOMMITTED (Dirty Reads Allowed)
-- =============================================================
PRINT '=== READ UNCOMMITTED DEMO ===';
GO

-- WINDOW 1: Update but don't commit
BEGIN TRANSACTION;
    UPDATE Customers SET Email = 'uncommitted@test.com' WHERE CustomerID = 1;
    PRINT 'Data updated but NOT committed';
    PRINT 'Leave this transaction open and check Window 2';
    
    -- DON'T COMMIT YET!
GO

-- WINDOW 2: Read uncommitted data (dirty read)
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT CustomerID, Email FROM Customers WHERE CustomerID = 1;
-- You'll see 'uncommitted@test.com' even though it's not committed!

PRINT 'Dirty read occurred - read uncommitted data';
GO

-- WINDOW 1: Rollback the change
ROLLBACK;
PRINT 'Transaction rolled back - that email never really existed!';
GO

-- =============================================================
-- DEMO 2: READ COMMITTED (Default - No Dirty Reads)
-- =============================================================
PRINT '=== READ COMMITTED DEMO ===';
GO

-- WINDOW 1: Update but don't commit
BEGIN TRANSACTION;
    UPDATE Customers SET Email = 'committed@test.com' WHERE CustomerID = 2;
    PRINT 'Data updated but NOT committed';
    PRINT 'Check Window 2 - it will BLOCK';
GO

-- WINDOW 2: Try to read (will block until commit)
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;  -- This is the default
SELECT CustomerID, Email FROM Customers WHERE CustomerID = 2;
-- This will BLOCK until Window 1 commits or rolls back

PRINT 'No dirty read - query waited for commit';
GO

-- WINDOW 1: Commit
COMMIT;
PRINT 'Committed - Window 2 can now read';
GO

-- =============================================================
-- DEMO 3: REPEATABLE READ (Prevents Non-Repeatable Reads)
-- =============================================================
PRINT '=== REPEATABLE READ DEMO ===';
GO

-- WINDOW 1: Read data with repeatable read
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

BEGIN TRANSACTION;
    SELECT CustomerID, Email FROM Customers WHERE CustomerID = 3;
    PRINT 'First read completed';
    PRINT 'Leave transaction open and try to update in Window 2';
GO

-- WINDOW 2: Try to update the same row
UPDATE Customers SET Email = 'changed@test.com' WHERE CustomerID = 3;
-- This will BLOCK because Window 1 holds shared lock

PRINT 'Update blocked by repeatable read lock';
GO

-- WINDOW 1: Read again (same result guaranteed)
SELECT CustomerID, Email FROM Customers WHERE CustomerID = 3;
PRINT 'Second read - same result guaranteed (repeatable read)';
COMMIT;
GO

-- =============================================================
-- DEMO 4: SERIALIZABLE (Prevents Phantom Reads)
-- =============================================================
PRINT '=== SERIALIZABLE DEMO ===';
GO

-- WINDOW 1: Read range with serializable
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION;
    SELECT COUNT(*) AS CustomerCount FROM Customers WHERE City = 'New York';
    PRINT 'First count completed';
    PRINT 'Try to insert new New York customer in Window 2';
GO

-- WINDOW 2: Try to insert new row in range
INSERT INTO Customers (FirstName, LastName, Email, City, State)
VALUES ('John', 'NewYork', 'john@newyork.com', 'New York', 'NY');
-- This will BLOCK because serializable locks the range

PRINT 'Insert blocked by serializable lock';
GO

-- WINDOW 1: Count again (same result - no phantoms)
SELECT COUNT(*) AS CustomerCount FROM Customers WHERE City = 'New York';
PRINT 'Second count - same result (no phantom rows)';
COMMIT;
GO