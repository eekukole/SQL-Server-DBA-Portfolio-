-- ========================================================================
-- SYNAGOGUE CHURCH MEMBER MANAGEMENT SYSTEM
-- Author: Emmanuel "The Executor" Ekukole
-- Date: February 2026
-- Description: Database for managing church members, donations, attendance,
--              and ministry groups
-- =========================================================================

USE master;
GO

-- Drop database if exists (for clean reinstall)
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'SynagogueChurchDB')
BEGIN
	ALTER DATABASE SynagogueChurchDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE SynagogueChurchDB;
END
GO

-- Create database
CREATE DATABASE SynagogueChurchDB
ON PRIMARY
(
	NAME = 'SynagogueChurchDB',
	FILENAME = 'E:\DEFAULT\DATA\SynagogueChurchDB_Data.mdf',
	SIZE = 100MB,
	MAXSIZE = 1000MB,
	FILEGROWTH = 10MB
)
LOG ON
(
	NAME = 'SynagogueChurchDB_log',
	FILENAME = 'L:\DEFAULT\LOG\SynagogueChurchDB_log.ldf',
	SIZE = 50MB,
	MAXSIZE = 500MB,
	FILEGROWTH = 5MB
);
GO

-- Create tables in the database
USE SynagogueChurchDB;
GO

--============================================================
-- TABLE 1: MEMBER (PARENT TABLE - No dependencies)
-- ===========================================================
CREATE TABLE Member
(
	MemberID INT IDENTITY(00001,1) NOT NULL,
	FirstName NVARCHAR(50) NOT NULL,
	LastName NVARCHAR(50) NOT NULL,
	Gender CHAR(1) NOT NULL,   -- M/F
	DateOfBirth DATE NOT NULL,
	PhoneNumber VARCHAR(10) NOT NULL,
	Email VARCHAR(25),
	HomeAddress NVARCHAR(100) NOT NULL,
	JoinDate DATE NOT NULL DEFAULT GETDATE(),
	Status VARCHAR(11) NOT NULL DEFAULT 'Active',  -- Active/Inactive/Transferred
	CreatedDate DATE NOT NULL DEFAULT GETDATE(),
	CreatedBy NVARCHAR(100) NOT NULL DEFAULT SUSER_SNAME(),

	-- CONSTRAINTS
	CONSTRAINT PK_Member PRIMARY KEY CLUSTERED (MemberID),
	CONSTRAINT UQ_Member_Phone UNIQUE (PhoneNumber),
	CONSTRAINT UQ_Member_Email UNIQUE (Email),
	CONSTRAINT CK_Member_Gender CHECK (Gender IN ('M', 'F')),
	CONSTRAINT CK_Member_Status CHECK (Status IN ('Active', 'Inactive', 'Transferred'))
);
GO

--============================================================
-- TABLE 2: CHURCHGROUP (PARENT TABLE - Can reference Member as Leader)
-- ===========================================================
CREATE TABLE ChurchGroup
(
	ChurchGroupID INT IDENTITY(01,1) NOT NULL,
	GroupName NVARCHAR(100) NOT NULL,
	GroupType VARCHAR(10) NOT NULL,  -- Ministry/Department/Age Group
	LeaderID INT NULL,  -- FK to Member (nullable if not leader yet)
	Description VARCHAR(500) NULL,
	IsActive BIT NOT NULL DEFAULT 1,
	CreatedDate DATE NOT NULL DEFAULT GETDATE(),

	--CONSTRAINTS
	CONSTRAINT PK_ChurchGroup PRIMARY KEY CLUSTERED (ChurchGroupID),
	CONSTRAINT UQ_ChurchGroup_Name UNIQUE (GroupName),
	CONSTRAINT CK_ChurchGroup_Type CHECK (GroupType IN ('Ministry','Department','Age Group'))
);
GO

-- Add FK to Member (after both tables exist)
ALTER TABLE ChurchGroup
ADD CONSTRAINT FK_ChurchGroup_Leader FOREIGN KEY (LeaderID)
	REFERENCES Member(MemberID);
GO


--============================================================
-- TABLE 3: DONATION (CHILD TABLE - depends on Member)
-- ===========================================================
CREATE TABLE Donation
(
	DonationID INT IDENTITY(000000001,1) NOT NULL,
	MemberID INT NOT NULL,  -- FK -> Member
	Amount DECIMAL(12),
	DonationDate DATE NOT NULL DEFAULT GETDATE(),
	DonationType VARCHAR(25) NOT NULL,  -- Tithe/Offering/Building Fund/Special
	PaymentMethod VARCHAR(15) NOT NULL,  -- Cash/Momo/Bank transfer
	Notes VARCHAR(500),
	CreatedDate DATE NOT NULL DEFAULT GETDATE(),
	
	--CONSTRAINTS
	CONSTRAINT PK_Donation PRIMARY KEY CLUSTERED (DonationID),
	CONSTRAINT FK_Donation_Member FOREIGN KEY (MemberID) REFERENCES Member(MemberID),
	CONSTRAINT CK_Donation_Type CHECK (DonationType IN ('Tithe','Offering','Building Fund','Special')),
	CONSTRAINT CK_Donation_Payment CHECK (PaymentMethod IN ('Cash','Momo','Bank transfer'))
);
GO


--============================================================
-- TABLE 4: ATTENDANCE (CHILD TABLE - depends on Member)
-- ===========================================================
CREATE TABLE Attendance
(
	AttendanceID INT IDENTITY(1,1) NOT NULL,
	MemberID INT NOT NULL,   -- FK -> Member
	ServiceDate DATE NOT NULL,
	ServiceType VARCHAR(15) NOT NULL,  -- Sunday Service/Midweek/Special Event
	IsPresent BIT DEFAULT 1 NOT NULL,
	CreatedDate DATE NOT NULL DEFAULT GETDATE()

	CONSTRAINT PK_Attendance PRIMARY KEY CLUSTERED (AttendanceID),
	CONSTRAINT FK_Attendance_Member FOREIGN KEY (MemberID) 
		REFERENCES Member(MemberID),
	CONSTRAINT CK_Attendance_Type CHECK (ServiceType IN ('Sunday service','Midweek','Special event'))
);
GO


--===========================================================================
-- TABLE 5: GROUPMEMBERSHIP (CHILD TABLE - depends on Member and ChurchGroup)
-- ==========================================================================
CREATE TABLE GroupMembership
(
	MembershipID INT IDENTITY(1,1) NOT NULL,
	MemberID INT NOT NULL, -- FK (Member)
	ChurchGroupID INT NOT NULL,  -- FK (ChurchGroup)
	JoinDate DATE NOT NULL DEFAULT GETDATE(),
	Role VARCHAR(10) NOT NULL DEFAULT 'Member',  -- Member/Leader/Assistant/Coordinator
	IsActive BIT NOT NULL DEFAULT 1,
	CreatedDate DATE NOT NULL DEFAULT GETDATE(),

	CONSTRAINT PK_GroupMembership PRIMARY KEY CLUSTERED (MembershipID),
	CONSTRAINT FK_GroupMembership_Member FOREIGN KEY (MemberID)
		REFERENCES Member(MemberID),
	CONSTRAINT FK_GroupMembership_Group FOREIGN KEY (ChurchGroupID)
		REFERENCES ChurchGroup(ChurchGroupID),
	CONSTRAINT CK_GroupMembership_Role CHECK (Role IN ('Member','Leader','Assistant','Coordinator')),

	-- Prevent duplicate: same member can't join same group twice (unless they left and rejoined)
	CONSTRAINT UQ_GroupMembership_MemberGroup UNIQUE (MemberID, ChurchGroupID)
);
GO


--============================================================
-- SAMPLE RECORDS FOR DEMONSTRATION
-- ===========================================================

-- INSERT MEMBERS (PARENT FIRST)
USE SynagogueChurchDB;
GO

INSERT INTO dbo.Member (FirstName, LastName, Gender, DateOfBirth, PhoneNumber, Email, HomeAddress, JoinDate, Status)
VALUES 
    ('Emmanuel', 'Ekukole', 'M', '1995-03-15', '671700400', 'eekukole@church.com', 'Douala, Littoral', '2020-01-10', 'Active'),
    ('Eposi', 'Suz', 'M', '1992-07-22', '677720610', 'eposi@church.com', 'Douala, Littoral', '2019-05-15', 'Active'),
    ('Bébé', 'Mbongo', 'F', '1998-11-30', '698756423', 'bebe@church.com', 'Yaoundé, Centre', '2021-03-20', 'Active'),
    ('Ndí', 'Fömë', 'M', '1990-01-05', '652550123', 'ndi@church.com', 'Limbe, Southwest', '2018-08-12', 'Active'),
    ('Sally', 'Nyolo', 'F', '1996-06-18', '671234567', 'sally@church.com', 'Douala, Littoral', '2022-02-14', 'Active');
GO


-- INSERT CHURCH GROUPS
INSERT INTO dbo.ChurchGroup (GroupName, GroupType, LeaderID, Description)
VALUES 
    ('Choir', 'Ministry', 1, 'Church worship team'),
    ('Youth Ministry', 'Ministry', 2, 'Young adults aged 18-35'),
    ('Ushers', 'Ministry', NULL, 'Service ushers and greeters'),
    ('Prayer Team', 'Ministry', 4, 'Intercessory prayer ministry'),
    ('Sunday School', 'Department', 3, 'Children and teen education');
GO


-- INSERT DONATIONS (CHILD - Member must exist first)
INSERT INTO dbo.Donation (MemberID, Amount, DonationDate, DonationType, PaymentMethod, Notes)
VALUES 
    (1, 50000, '2026-01-05', 'Tithe', 'MoMo', 'January tithe'),
    (1, 25000, '2026-01-12', 'Offering', 'Cash', 'Sunday offering'),
    (2, 75000, '2026-01-10', 'Tithe', 'Bank Transfer', 'Monthly tithe'),
    (3, 30000, '2026-01-15', 'Building Fund', 'MoMo', 'New sanctuary project'),
    (4, 100000, '2026-01-20', 'Offering', 'Cash', 'Thanksgiving offering'),
    (5, 20000, '2026-01-25', 'Offering', 'MoMo', 'Weekly offering');
GO


-- INSERT ATTENDANCE RECORDS
INSERT INTO dbo.Attendance (MemberID, ServiceDate, ServiceType, IsPresent)
VALUES 
    (1, '2026-01-05', 'Sunday Service', 1),
    (1, '2026-01-08', 'Midweek', 1),
    (1, '2026-01-12', 'Sunday Service', 1),
    (2, '2026-01-05', 'Sunday Service', 1),
    (2, '2026-01-12', 'Sunday Service', 0),  -- Absent
    (3, '2026-01-05', 'Sunday Service', 1),
    (3, '2026-01-08', 'Midweek', 1),
    (4, '2026-01-05', 'Sunday Service', 1),
    (5, '2026-01-12', 'Sunday Service', 1);
GO

-- INSERT GROUP MEMBERSHIPS
INSERT INTO dbo.GroupMembership (MemberID, ChurchGroupID, JoinDate, Role)
VALUES 
    (1, 1, '2020-02-01', 'Member'),  -- Emmanuel in Choir
    (1, 2, '2020-02-01', 'Leader'),  -- Emmanuel leads Youth (but LeaderID in Group table points to member 2)
    (2, 2, '2019-06-01', 'Leader'),  -- Eposi leads Youth
    (3, 5, '2021-04-01', 'Leader'),  -- Bébé leads Sunday School
    (4, 4, '2018-09-01', 'Leader'),  -- Ndí leads Prayer Team
    (5, 3, '2022-03-01', 'Member');  -- Sally in Ushers
GO




-- =============================================================================
-- USEFUL QUERIES FOR CHURCH ADMINS
-- =============================================================================

-- Query 1: All active members with contact info
SELECT 
    MemberID,
    FirstName + ' ' + LastName AS FullName,
    Gender,
    PhoneNumber,
    Email,
    JoinDate,
    DATEDIFF(YEAR, JoinDate, GETDATE()) AS YearsAsMember
FROM dbo.Member
WHERE Status = 'Active'
ORDER BY LastName, FirstName;


-- Query 2: Monthly donation summary
SELECT 
    MONTH(DonationDate) AS Month,
    YEAR(DonationDate) AS Year,
    DonationType,
    COUNT(*) AS NumberOfDonations,
    SUM(Amount) AS TotalAmount,
    AVG(Amount) AS AverageAmount
FROM dbo.Donation
WHERE YEAR(DonationDate) = 2026
GROUP BY YEAR(DonationDate), MONTH(DonationDate), DonationType
ORDER BY Year, Month, DonationType;


-- Query 3: Top 10 donors (lifetime)
SELECT TOP 10
    m.FirstName + ' ' + m.LastName AS MemberName,
    m.PhoneNumber,
    COUNT(d.DonationID) AS NumberOfDonations,
    SUM(d.Amount) AS TotalDonated,
    MAX(d.DonationDate) AS LastDonationDate
FROM dbo.Member m
JOIN dbo.Donation d ON m.MemberID = d.MemberID
GROUP BY m.MemberID, m.FirstName, m.LastName, m.PhoneNumber
ORDER BY TotalDonated DESC;


-- Query 4: Attendance rate by member (last 3 months)
SELECT 
    m.FirstName + ' ' + m.LastName AS MemberName,
    COUNT(CASE WHEN a.IsPresent = 1 THEN 1 END) AS TimesPresent,
    COUNT(*) AS TotalServices,
    CAST(COUNT(CASE WHEN a.IsPresent = 1 THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS AttendanceRate
FROM dbo.Member m
LEFT JOIN dbo.Attendance a ON m.MemberID = a.MemberID
WHERE a.ServiceDate >= DATEADD(MONTH, -3, GETDATE())
GROUP BY m.MemberID, m.FirstName, m.LastName
ORDER BY AttendanceRate DESC;


-- Query 5: Members by ministry group
SELECT 
    g.GroupName,
    g.GroupType,
    ISNULL(leader.FirstName + ' ' + leader.LastName, 'No Leader') AS GroupLeader,
    COUNT(gm.MembershipID) AS MemberCount
FROM dbo.ChurchGroup g
LEFT JOIN dbo.Member leader ON g.LeaderID = leader.MemberID
LEFT JOIN dbo.GroupMembership gm ON g.ChurchGroupID = gm.ChurchGroupID AND gm.IsActive = 1
WHERE g.IsActive = 1
GROUP BY g.ChurchGroupID, g.GroupName, g.GroupType, leader.FirstName, leader.LastName
ORDER BY MemberCount DESC;


-- Query 6: Members who haven't donated in 3+ months
SELECT 
    m.FirstName + ' ' + m.LastName AS MemberName,
    m.PhoneNumber,
    MAX(d.DonationDate) AS LastDonationDate,
    DATEDIFF(DAY, MAX(d.DonationDate), GETDATE()) AS DaysSinceLastDonation
FROM dbo.Member m
LEFT JOIN dbo.Donation d ON m.MemberID = d.MemberID
WHERE m.Status = 'Active'
GROUP BY m.MemberID, m.FirstName, m.LastName, m.PhoneNumber
HAVING MAX(d.DonationDate) < DATEADD(MONTH, -3, GETDATE()) OR MAX(d.DonationDate) IS NULL
ORDER BY DaysSinceLastDonation DESC;


-- Query 7: Service attendance summary
SELECT 
    ServiceDate,
    ServiceType,
    COUNT(CASE WHEN IsPresent = 1 THEN 1 END) AS PresentCount,
    COUNT(CASE WHEN IsPresent = 0 THEN 1 END) AS AbsentCount,
    COUNT(*) AS TotalRecorded
FROM dbo.Attendance
WHERE ServiceDate >= DATEADD(MONTH, -1, GETDATE())
GROUP BY ServiceDate, ServiceType
ORDER BY ServiceDate DESC;