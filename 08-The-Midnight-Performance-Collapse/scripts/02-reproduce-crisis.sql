-- =============================================================
-- CRISIS SIMULATION: Simulate 100 concurrent users
-- =============================================================
USE MedicalRecords_PROD;
GO

PRINT '========================================';
PRINT 'SIMULATING PRODUCTION CRISIS';
PRINT 'Time: 11:30 PM - Peak ER activity';
PRINT 'Concurrent users: 100+';
PRINT 'Expected behavior: Slow responses, blocking';
PRINT '========================================';
PRINT '';
GO

-- Simulate 100 users accessing patient histories
-- (In real production, this would be the application)
DECLARE @Counter INT = 1;
DECLARE @MRN VARCHAR(20);

WHILE @Counter <= 100
BEGIN
    SET @MRN = 'MRN' + RIGHT('000000' + CAST(@Counter AS VARCHAR(6)), 6);
    
    -- Each "user" calls the problematic stored procedure
    EXEC usp_GetPatientHistory @MRN;
    
    SET @Counter = @Counter + 1;
END;
GO

-- Run this 3-5 times in different query windows to simulate concurrent load
-- You should see performance degrade significantly

PRINT 'Crisis simulation complete';
PRINT 'Check Activity Monitor (Ctrl+Alt+A) - you should see high CPU and blocking';
GO