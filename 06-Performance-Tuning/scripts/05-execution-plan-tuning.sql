-- =============================================================
-- THE RELATIONAL ENGINE
-- =============================================================
/*
Key points:

Three key components:
1. Query Parser - Checks syntax and converts to machine language
2. Query Optimizer - Prepares execution plan using query statistics
3. Query Executor - Executes the query following the execution plan

What is an Execution Plan:
"It is the most efficient and least cost roadmap, which contains 
the order of all the steps to be performed as part of the query execution."

Storage Engine:
"Responsible for storage and retrieval of data on storage system 
(disk, SAN, etc.), data manipulation, locking and managing transactions."
*/

USE PerformanceLab;
GO

-- =============================================================
-- EXERCISE: Watch Query Parser, Optimizer, Executor Work
-- =============================================================

-- Enable execution plan (Ctrl+M in SSMS)
SET SHOWPLAN_XML ON;
GO

-- This query will be parsed, optimized, but NOT executed
SELECT * FROM Customers WHERE City = 'Chicago';
GO

SET SHOWPLAN_XML OFF;
GO

-- The XML you see is from the Query Optimizer
-- It shows the "most efficient and least cost roadmap"

-- =============================================================
-- EXERCISE: Compare Parser Behavior
-- =============================================================

-- Good syntax - Parser accepts
SELECT * FROM Customers WHERE CustomerID = 1;
GO

-- Bad syntax - Parser rejects (won't even reach optimizer!)
-- Uncomment to test:
-- SELCT * FROM Customers WHERE CustomerID = 1;
-- Error: Incorrect syntax near 'SELCT'

-- Parser catches this BEFORE optimization