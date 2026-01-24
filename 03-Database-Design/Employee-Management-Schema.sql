/*
============================================================================
PROJECT: Employee Management Database Design
AUTHOR: Emmanuel Ekukole
DATE: 24 January 2026
DESCRIPTION: Relational database demonstrating normalized table design,
             foreign key relationships, and data integrity constraints.
             
FEATURES:
- Three-table hierarchy (Department → Employee → EmployeeSalary)
- Primary keys with IDENTITY
- Foreign key relationships with referential integrity
- Check constraints for data validation
- Unique constraints on business keys
- Audit columns (CreatedDate, IsActive)
- Proper data type selection (NVARCHAR for international, VARCHAR for ASCII)

USAGE: Run this script against a SQL Server 2017+ instance
============================================================================
*/

-- Set database context (adjust to your database name)
USE YourDatabaseName;  
GO

-- ============================================================================
-- CLEANUP: Drop existing tables (in reverse dependency order)
-- ============================================================================
IF OBJECT_ID('dbo.EmployeeSalary', 'U') IS NOT NULL 
    DROP TABLE dbo.EmployeeSalary;
IF OBJECT_ID('dbo.Employee', 'U') IS NOT NULL 
    DROP TABLE dbo.Employee;
IF OBJECT_ID('dbo.Department', 'U') IS NOT NULL 
    DROP TABLE dbo.Department;
GO

-- ============================================================================
-- TABLE 1: DEPARTMENT
-- Purpose: Store organizational departments
-- ============================================================================
CREATE TABLE dbo.Department
(
    DepartmentID INT IDENTITY(1,1) NOT NULL,
    DepartmentName NVARCHAR(100) NOT NULL,
    ManagerName NVARCHAR(100) NULL,
    Budget DECIMAL(18,2) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT PK_Department PRIMARY KEY CLUSTERED (DepartmentID),
    CONSTRAINT UQ_Department_Name UNIQUE (DepartmentName),
    CONSTRAINT CK_Department_Budget CHECK (Budget >= 0 OR Budget IS NULL)
);
GO

-- ============================================================================
-- TABLE 2: EMPLOYEE
-- Purpose: Store employee records with department assignment
-- ============================================================================
CREATE TABLE dbo.Employee
(
    EmployeeID INT IDENTITY(1,1) NOT NULL,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email VARCHAR(100) NOT NULL,
    DepartmentID INT NOT NULL,
    HireDate DATE NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT PK_Employee PRIMARY KEY CLUSTERED (EmployeeID),
    CONSTRAINT UQ_Employee_Email UNIQUE (Email),
    CONSTRAINT FK_Employee_Department FOREIGN KEY (DepartmentID) 
        REFERENCES dbo.Department(DepartmentID),
    CONSTRAINT CK_Employee_Email CHECK (Email LIKE '%@%.%'),
    CONSTRAINT CK_Employee_HireDate CHECK (HireDate <= CAST(SYSDATETIME() AS DATE))
);
GO

-- ============================================================================
-- TABLE 3: EMPLOYEE SALARY
-- Purpose: Track salary history for employees
-- ============================================================================
CREATE TABLE dbo.EmployeeSalary
(
    SalaryID INT IDENTITY(1,1) NOT NULL,
    EmployeeID INT NOT NULL,
    SalaryAmount DECIMAL(18,2) NOT NULL,
    EffectiveDate DATE NOT NULL,
    EndDate DATE NULL,
    IsCurrentSalary BIT NOT NULL DEFAULT 1,
    CreatedDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    
    CONSTRAINT PK_EmployeeSalary PRIMARY KEY CLUSTERED (SalaryID),
    CONSTRAINT FK_Salary_Employee FOREIGN KEY (EmployeeID) 
        REFERENCES dbo.Employee(EmployeeID),
    CONSTRAINT CK_Salary_Amount CHECK (SalaryAmount > 0),
    CONSTRAINT CK_Salary_Dates CHECK (EndDate IS NULL OR EndDate >= EffectiveDate)
);
GO

-- ============================================================================
-- SAMPLE DATA
-- ============================================================================

-- Insert Departments
INSERT INTO dbo.Department (DepartmentName, ManagerName, Budget)
VALUES 
    ('Engineering', 'Alice Johnson', 500000.00),
    ('Sales', 'Bob Martinez', 300000.00),
    ('HR', 'Carol White', 150000.00),
    ('IT Operations', 'David Chen', 250000.00);

-- Insert Employees
INSERT INTO dbo.Employee (FirstName, LastName, Email, DepartmentID, HireDate)
VALUES 
    ('David', 'Kim', 'david.kim@company.com', 1, '2024-01-15'),
    ('Emma', 'Brown', 'emma.brown@company.com', 1, '2024-03-20'),
    ('Frank', 'Davis', 'frank.davis@company.com', 2, '2023-11-10'),
    ('Grace', 'Lee', 'grace.lee@company.com', 3, '2025-06-01'),
    ('Hassan', 'Ahmed', 'hassan.ahmed@company.com', 4, '2024-07-15'),
    ('María', 'García', 'maria.garcia@company.com', 2, '2025-01-10');

-- Insert Salary History
INSERT INTO dbo.EmployeeSalary (EmployeeID, SalaryAmount, EffectiveDate, IsCurrentSalary)
VALUES 
    -- David's salary progression
    (1, 85000.00, '2024-01-15', 0),
    (1, 92000.00, '2025-01-15', 1),
    -- Emma
    (2, 78000.00, '2024-03-20', 1),
    -- Frank
    (3, 65000.00, '2023-11-10', 0),
    (3, 72000.00, '2024-11-10', 1),
    -- Grace
    (4, 55000.00, '2025-06-01', 1),
    -- Hassan
    (5, 95000.00, '2024-07-15', 1),
    -- María
    (6, 68000.00, '2025-01-10', 1);
GO

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Query 1: All employees with their departments
SELECT 
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName AS FullName,
    e.Email,
    d.DepartmentName,
    e.HireDate,
    DATEDIFF(MONTH, e.HireDate, GETDATE()) AS MonthsEmployed
FROM dbo.Employee e
INNER JOIN dbo.Department d ON e.DepartmentID = d.DepartmentID
WHERE e.IsActive = 1
ORDER BY d.DepartmentName, e.LastName;

-- Query 2: Current salaries by department
SELECT 
    d.DepartmentName,
    e.FirstName + ' ' + e.LastName AS FullName,
    FORMAT(s.SalaryAmount, 'C', 'en-US') AS CurrentSalary,
    s.EffectiveDate
FROM dbo.EmployeeSalary s
INNER JOIN dbo.Employee e ON s.EmployeeID = e.EmployeeID
INNER JOIN dbo.Department d ON e.DepartmentID = d.DepartmentID
WHERE s.IsCurrentSalary = 1
ORDER BY d.DepartmentName, s.SalaryAmount DESC;

-- Query 3: Salary history for specific employee (David Kim)
SELECT 
    e.FirstName + ' ' + e.LastName AS FullName,
    FORMAT(s.SalaryAmount, 'C', 'en-US') AS Salary,
    s.EffectiveDate,
    s.EndDate,
    CASE WHEN s.IsCurrentSalary = 1 THEN 'Current' ELSE 'Historical' END AS Status
FROM dbo.EmployeeSalary s
INNER JOIN dbo.Employee e ON s.EmployeeID = e.EmployeeID
WHERE e.EmployeeID = 1
ORDER BY s.EffectiveDate;

-- Query 4: Department budget vs total current salaries
SELECT 
    d.DepartmentName,
    FORMAT(d.Budget, 'C', 'en-US') AS DepartmentBudget,
    FORMAT(SUM(s.SalaryAmount), 'C', 'en-US') AS TotalSalaries,
    FORMAT(d.Budget - SUM(s.SalaryAmount), 'C', 'en-US') AS RemainingBudget,
    COUNT(e.EmployeeID) AS EmployeeCount
FROM dbo.Department d
LEFT JOIN dbo.Employee e ON d.DepartmentID = e.DepartmentID AND e.IsActive = 1
LEFT JOIN dbo.EmployeeSalary s ON e.EmployeeID = s.EmployeeID AND s.IsCurrentSalary = 1
GROUP BY d.DepartmentName, d.Budget
ORDER BY d.DepartmentName;

-- ============================================================================
-- SCHEMA DOCUMENTATION
-- ============================================================================

-- View table structures
EXEC sp_help 'dbo.Department';
EXEC sp_help 'dbo.Employee';
EXEC sp_help 'dbo.EmployeeSalary';

-- View foreign key relationships
SELECT 
    OBJECT_NAME(f.parent_object_id) AS TableName,
    COL_NAME(fc.parent_object_id, fc.parent_column_id) AS ColumnName,
    OBJECT_NAME(f.referenced_object_id) AS ReferencedTable,
    COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS ReferencedColumn,
    f.name AS ForeignKeyName
FROM sys.foreign_keys AS f
INNER JOIN sys.foreign_key_columns AS fc ON f.object_id = fc.constraint_object_id
WHERE OBJECT_NAME(f.parent_object_id) IN ('Employee', 'EmployeeSalary')
ORDER BY TableName;

/*
============================================================================
LESSONS LEARNED:
1. Foreign keys enforce referential integrity at database level
2. IDENTITY columns auto-generate sequential IDs (no manual management)
3. Check constraints validate data rules (email format, positive salaries)
4. Audit columns (CreatedDate, IsActive) enable tracking and soft deletes
5. NVARCHAR for international names (María, Hassan) vs VARCHAR for emails
6. DECIMAL(18,2) for financial data (precise, no floating-point errors)
7. Normalized design prevents data duplication and anomalies

NEXT STEPS:
- Add indexes for performance (Module 5)
- Create stored procedures for CRUD operations (Module 7)
- Implement triggers for automatic salary history management (Module 7)
- Add temporal tables for automatic change tracking (Advanced)
============================================================================
*/
