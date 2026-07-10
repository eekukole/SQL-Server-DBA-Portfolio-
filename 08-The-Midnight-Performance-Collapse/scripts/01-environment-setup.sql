-- =============================================================
-- SETUP: MedicalRecords Production Database
-- =============================================================
CREATE DATABASE MedicalRecords_PROD;
GO

USE MedicalRecords_PROD;
GO

-- Patient records table (mission-critical)
CREATE TABLE Patients (
    PatientID INT PRIMARY KEY IDENTITY(1,1),
    MRN VARCHAR(20) UNIQUE NOT NULL, -- Medical Record Number
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    DateOfBirth DATE,
    SSN VARCHAR(11),
    LastVisitDate DATETIME,
    InsuranceProvider VARCHAR(100),
    PrimaryCarePhysician VARCHAR(100),
    CreateDate DATETIME DEFAULT GETDATE(),
    ModifiedDate DATETIME DEFAULT GETDATE()
);

-- Medical encounters (ER visits, appointments)
CREATE TABLE Encounters (
    EncounterID INT PRIMARY KEY IDENTITY(1,1),
    PatientID INT NOT NULL,
    EncounterDate DATETIME NOT NULL,
    EncounterType VARCHAR(50), -- ER, Outpatient, Inpatient
    ChiefComplaint VARCHAR(500),
    AttendingPhysician VARCHAR(100),
    FacilityCode VARCHAR(20),
    Status VARCHAR(20), -- Active, Closed, Pending
    CreateDate DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (PatientID) REFERENCES Patients(PatientID)
);

-- Medications prescribed
CREATE TABLE Medications (
    MedicationID INT PRIMARY KEY IDENTITY(1,1),
    EncounterID INT NOT NULL,
    DrugName VARCHAR(200),
    Dosage VARCHAR(50),
    Frequency VARCHAR(50),
    PrescribedDate DATETIME,
    FOREIGN KEY (EncounterID) REFERENCES Encounters(EncounterID)
);

-- Audit log (compliance requirement - HIPAA)
CREATE TABLE AuditLog (
    AuditID INT PRIMARY KEY IDENTITY(1,1),
    EventType VARCHAR(50),
    TableName VARCHAR(100),
    RecordID INT,
    UserName VARCHAR(100),
    EventDate DATETIME DEFAULT GETDATE(),
    Details VARCHAR(MAX)
);

-- =============================================================
-- POPULATE WITH REALISTIC DATA
-- =============================================================

-- 50,000 patients
INSERT INTO Patients (MRN, FirstName, LastName, DateOfBirth, SSN, LastVisitDate, InsuranceProvider, PrimaryCarePhysician)
SELECT TOP 50000
    'MRN' + RIGHT('000000' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(6)), 6),
    'Patient' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(10)),
    'Last' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(10)),
    DATEADD(YEAR, -(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 80 + 1), GETDATE()),
    RIGHT('000-00-' + CAST(1000 + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 9000 AS VARCHAR(4)), 11),
    DATEADD(DAY, -(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 365), GETDATE()),
    CASE (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 5)
        WHEN 0 THEN 'BlueCross'
        WHEN 1 THEN 'Aetna'
        WHEN 2 THEN 'UnitedHealth'
        WHEN 3 THEN 'Cigna'
        ELSE 'Medicare'
    END,
    'Dr. ' + CASE (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 20)
        WHEN 0 THEN 'Smith'
        WHEN 1 THEN 'Johnson'
        WHEN 2 THEN 'Williams'
        ELSE 'Provider' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 20 AS VARCHAR(3))
    END
FROM sys.all_columns a
CROSS JOIN sys.all_columns b;

PRINT 'Patients loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- 200,000 encounters (average 4 per patient)
INSERT INTO Encounters (PatientID, EncounterDate, EncounterType, ChiefComplaint, AttendingPhysician, FacilityCode, Status)
SELECT TOP 200000
    (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 50000) + 1,
    DATEADD(HOUR, -(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 8760), GETDATE()), -- Past year
    CASE (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 3)
        WHEN 0 THEN 'ER'
        WHEN 1 THEN 'Outpatient'
        ELSE 'Inpatient'
    END,
    CASE (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 10)
        WHEN 0 THEN 'Chest pain'
        WHEN 1 THEN 'Abdominal pain'
        WHEN 2 THEN 'Fever'
        WHEN 3 THEN 'Headache'
        WHEN 4 THEN 'Shortness of breath'
        ELSE 'Other symptoms'
    END,
    'Dr. Attending' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 50 AS VARCHAR(3)),
    'FAC' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 10 AS VARCHAR(3)),
    CASE (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 5)
        WHEN 0 THEN 'Active'
        WHEN 1 THEN 'Pending'
        ELSE 'Closed'
    END
FROM sys.all_columns a
CROSS JOIN sys.all_columns b;

PRINT 'Encounters loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- 300,000 medications
INSERT INTO Medications (EncounterID, DrugName, Dosage, Frequency, PrescribedDate)
SELECT TOP 300000
    (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 200000) + 1,
    CASE (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 10)
        WHEN 0 THEN 'Lisinopril'
        WHEN 1 THEN 'Metformin'
        WHEN 2 THEN 'Atorvastatin'
        WHEN 3 THEN 'Amlodipine'
        WHEN 4 THEN 'Metoprolol'
        ELSE 'Generic Drug ' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 100 AS VARCHAR(3))
    END,
    CAST((ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 500 + 10) AS VARCHAR(10)) + 'mg',
    CASE (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 4)
        WHEN 0 THEN 'Once daily'
        WHEN 1 THEN 'Twice daily'
        WHEN 2 THEN 'Three times daily'
        ELSE 'As needed'
    END,
    DATEADD(DAY, -(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 365), GETDATE())
FROM sys.all_columns a
CROSS JOIN sys.all_columns b;

PRINT 'Medications loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- Create indexes (some missing - this is part of the problem!)
CREATE NONCLUSTERED INDEX IX_Patients_LastVisit ON Patients(LastVisitDate);
CREATE NONCLUSTERED INDEX IX_Encounters_PatientID ON Encounters(PatientID);
-- MISSING: Index on Encounters(EncounterDate, Status)
-- MISSING: Index on Medications(EncounterID)

PRINT '';
PRINT 'Production environment created successfully';
PRINT 'Database size: ~100MB';
PRINT '';
GO






-- =============================================================
-- THE PROBLEMATIC STORED PROCEDURE
-- (Application calls this every time a doctor opens patient record)
-- =============================================================
USE MedicalRecords_PROD;
GO

CREATE PROCEDURE usp_GetPatientHistory
    @MRN VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Get patient info
    DECLARE @PatientID INT;
    
    SELECT @PatientID = PatientID
    FROM Patients
    WHERE MRN = @MRN;
    
    -- Get recent encounters (PROBLEM: No index on EncounterDate + Status)
    SELECT 
        e.EncounterID,
        e.EncounterDate,
        e.EncounterType,
        e.ChiefComplaint,
        e.AttendingPhysician,
        e.Status
    FROM Encounters e
    WHERE e.PatientID = @PatientID
        AND e.Status IN ('Active', 'Pending')  -- Filter on non-indexed column
        AND e.EncounterDate >= DATEADD(YEAR, -2, GETDATE())  -- Past 2 years
    ORDER BY e.EncounterDate DESC;  -- Expensive sort
    
    -- Get medications for each encounter (PROBLEM: Cursor + missing index)
    DECLARE @EncounterID INT;
    DECLARE @TempMeds TABLE (
        EncounterID INT,
        MedicationList VARCHAR(MAX)
    );
    
    DECLARE encounter_cursor CURSOR FOR
    SELECT EncounterID 
    FROM Encounters
    WHERE PatientID = @PatientID
        AND Status IN ('Active', 'Pending');
    
    OPEN encounter_cursor;
    FETCH NEXT FROM encounter_cursor INTO @EncounterID;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @MedList VARCHAR(MAX) = '';
        
        -- Get all medications (PROBLEM: No index on Medications.EncounterID)
        SELECT @MedList = @MedList + DrugName + ', '
        FROM Medications
        WHERE EncounterID = @EncounterID;
        
        INSERT INTO @TempMeds VALUES (@EncounterID, @MedList);
        
        FETCH NEXT FROM encounter_cursor INTO @EncounterID;
    END;
    
    CLOSE encounter_cursor;
    DEALLOCATE encounter_cursor;
    
    -- Return medications
    SELECT * FROM @TempMeds;
    
    -- Audit log (PROBLEM: INSERT on every call = log contention)
    INSERT INTO AuditLog (EventType, TableName, RecordID, UserName, Details)
    VALUES ('PatientHistoryAccess', 'Patients', @PatientID, SUSER_NAME(), 
            'Accessed patient history for MRN: ' + @MRN);
END;
GO

PRINT 'Stored procedure created: usp_GetPatientHistory';
PRINT 'WARNING: This procedure has multiple performance issues!';
GO