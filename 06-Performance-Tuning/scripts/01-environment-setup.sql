-- ENVIRONMENT SETUP
/* Prerequisite: a test database which to simulate performance bottlenecks and then go on to troubleshoot. 

I created 3 tables within the database: Customers, OrderDetails, and Orders.
*/

-- =============================================================
-- SETUP: Create Performance Test Database
-- =============================================================
CREATE DATABASE PerformanceLab;
GO

USE PerformanceLab;
GO

-- Create test tables
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY IDENTITY(1,1),
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Email VARCHAR(100),
    City VARCHAR(50),
    State CHAR(2),
    CreateDate DATETIME DEFAULT GETDATE()
);

CREATE TABLE Orders (
    OrderID INT PRIMARY KEY IDENTITY(1,1),
    CustomerID INT,
    OrderDate DATETIME DEFAULT GETDATE(),
    Amount DECIMAL(10,2),
    Status VARCHAR(20)
);

CREATE TABLE OrderDetails (
    OrderDetailID INT PRIMARY KEY IDENTITY(1,1),
    OrderID INT,
    ProductID INT,
    Quantity INT,
    UnitPrice DECIMAL(10,2)
);

-- =============================================================
-- Insert 20,000 customers
-- =============================================================
INSERT INTO Customers (FirstName, LastName, Email, City, State)
SELECT TOP 20000
    'First' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(10)),
    'Last' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(10)),
    'email' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(10)) + '@test.com',
    CASE (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 10)
        WHEN 0 THEN 'New York'
        WHEN 1 THEN 'Los Angeles'
        WHEN 2 THEN 'Chicago'
        WHEN 3 THEN 'Houston'
        WHEN 4 THEN 'Phoenix'
        WHEN 5 THEN 'Philadelphia'
        WHEN 6 THEN 'San Antonio'
        WHEN 7 THEN 'San Diego'
        WHEN 8 THEN 'Dallas'
        ELSE 'Austin'
    END,
    'CA'
FROM sys.all_columns a
CROSS JOIN sys.all_columns b;

PRINT 'Customers loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- =============================================================
-- Insert 100,000 orders
-- =============================================================
INSERT INTO Orders (CustomerID, OrderDate, Amount, Status)
SELECT TOP 100000
    (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 20000) + 1,  -- CustomerID 1-20000
    DATEADD(DAY, -(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 365), GETDATE()),
    CAST((ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 1000) + 10.00 AS DECIMAL(10,2)),
    CASE (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 3)
        WHEN 0 THEN 'Pending'
        WHEN 1 THEN 'Shipped'
        ELSE 'Delivered'
    END
FROM sys.all_columns a
CROSS JOIN sys.all_columns b;

PRINT 'Orders loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- =============================================================
-- Insert 200,000 order details
-- =============================================================
INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
SELECT TOP 200000
    (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 100000) + 1,  -- OrderID 1-100000
    (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 500) + 1,     -- ProductID 1-500
    (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 10) + 1,      -- Quantity 1-10
    CAST((ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 200) + 5.00 AS DECIMAL(10,2))
FROM sys.all_columns a
CROSS JOIN sys.all_columns b;

PRINT 'OrderDetails loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- =============================================================
-- Verify data load
-- =============================================================
PRINT '';
PRINT 'Final Row Counts:';
PRINT '==================';

SELECT 'Customers' AS TableName, COUNT(*) AS RowCount FROM Customers
UNION ALL
SELECT 'Orders', COUNT(*) FROM Orders
UNION ALL
SELECT 'OrderDetails', COUNT(*) FROM OrderDetails;
GO

-- Expected output:
-- Customers: 20,000
-- Orders: 100,000
-- OrderDetails: 200,000





