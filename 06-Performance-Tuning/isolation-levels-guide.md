\# SQL Server Isolation Levels - Complete Guide



\## The Four Isolation Levels



| Isolation Level | Dirty Reads | Non-Repeatable Reads | Phantom Reads | Concurrency | Use Case |

|----------------|-------------|---------------------|---------------|-------------|----------|

| \*\*READ UNCOMMITTED\*\* | ✅ Allowed | ✅ Allowed | ✅ Allowed | Highest | Reports where exact data doesn't matter |

| \*\*READ COMMITTED\*\* (Default) | ❌ Prevented | ✅ Allowed | ✅ Allowed | High | Standard OLTP applications |

| \*\*REPEATABLE READ\*\* | ❌ Prevented | ❌ Prevented | ✅ Allowed | Medium | Financial transactions |

| \*\*SERIALIZABLE\*\* | ❌ Prevented | ❌ Prevented | ❌ Prevented | Lowest | Critical operations requiring absolute consistency |



\## Read Phenomena Explained



\### 1. Dirty Read

\*\*What it is:\*\* Reading data that has been modified but not yet committed



\*\*Example:\*\*

\- Transaction A updates Customer balance to $1000 (not committed)

\- Transaction B reads balance as $1000

\- Transaction A rolls back

\- Transaction B acted on data that never actually existed!



\*\*Prevented by:\*\* READ COMMITTED, REPEATABLE READ, SERIALIZABLE



\---



\### 2. Non-Repeatable Read

\*\*What it is:\*\* Reading the same row twice in a transaction gets different values



\*\*Example:\*\*

\- Transaction A reads Customer balance: $500

\- Transaction B updates balance to $1000 and commits

\- Transaction A reads same Customer balance again: $1000 (different!)



\*\*Prevented by:\*\* REPEATABLE READ, SERIALIZABLE



\---



\### 3. Phantom Read

\*\*What it is:\*\* Executing the same query twice in a transaction returns different rows



\*\*Example:\*\*

\- Transaction A counts Customers in New York: 100

\- Transaction B inserts new New York Customer and commits

\- Transaction A counts again: 101 (phantom row appeared!)



\*\*Prevented by:\*\* SERIALIZABLE only



\---



\## ACID Properties



Key point:

"Isolation is the third property of the ACID (Atomicity, Consistency, Isolation, Durability) 

standards that ensure data remains consistent and accurate."



\### A - Atomicity

All or nothing - transaction either completes fully or not at all



\### C - Consistency

Data must be valid according to defined rules and constraints



\### I - Isolation

Concurrent transactions don't interfere with each other



\### D - Durability

Once committed, data persists even after system failure



\---



\## Choosing the Right Isolation Level



\### Use READ UNCOMMITTED when:

\- Running reports where approximate data is acceptable

\- Performance is critical

\- Data accuracy is less important than speed

\- Example: Real-time dashboard showing "approximately 10,523 orders today"



\### Use READ COMMITTED when:

\- Standard business applications

\- Balance between consistency and performance needed

\- Most OLTP systems (this is SQL Server default)

\- Example: E-commerce order processing



\### Use REPEATABLE READ when:

\- Financial calculations

\- Need consistent view of data during transaction

\- Calculations depend on data not changing mid-transaction

\- Example: Bank account transfers (balance shouldn't change during transfer)



\### Use SERIALIZABLE when:

\- Critical operations requiring absolute consistency

\- Regulatory compliance requirements

\- Audit trails

\- Example: Month-end financial closing



\---



\## Syntax Examples



```sql

\-- Set isolation level for current session

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;



\-- Set for specific query using table hint

SELECT \* FROM Customers WITH (NOLOCK);          -- READ UNCOMMITTED

SELECT \* FROM Customers WITH (READCOMMITTED);   -- READ COMMITTED

SELECT \* FROM Customers WITH (REPEATABLEREAD);  -- REPEATABLE READ

SELECT \* FROM Customers WITH (SERIALIZABLE);    -- SERIALIZABLE

SELECT \* FROM Customers WITH (HOLDLOCK);        -- Equivalent to SERIALIZABLE

```



\---



\## Performance vs Consistency Trade-off


SERIALIZABLE     ████████████████  Highest Consistency
███               Lowest Performance
REPEATABLE READ  ████████████      High Consistency
██████            Medium Performance
READ COMMITTED   ████████          Medium Consistency
████████          High Performance
READ UNCOMMITTED ████              Lowest Consistency
████████████████  Highest Performance



---

## Real-World Decision Matrix

**Question 1:** Can the application tolerate reading uncommitted data?
- YES → Consider READ UNCOMMITTED (reporting only!)
- NO → Go to Question 2

**Question 2:** Must the same row return identical values within a transaction?
- YES → Go to Question 3
- NO → Use READ COMMITTED (default)

**Question 3:** Must the same query return identical rows within a transaction?
- YES → Use SERIALIZABLE
- NO → Use REPEATABLE READ

---

## Interview Answers

**Q: "What's the default isolation level in SQL Server?"**
**A:** "READ COMMITTED. It prevents dirty reads but allows non-repeatable reads and phantom reads. This provides a good balance between data consistency and concurrency for most OLTP applications."

**Q: "When would you use READ UNCOMMITTED?"**
**A:** "Only for reporting queries where approximate data is acceptable and performance is critical. For example, a dashboard showing 'approximately 10,000 active users' doesn't need exact precision. However, I'd never use it for transactional data because dirty reads could show data that gets rolled back, leading to incorrect business decisions."

**Q: "What's the difference between REPEATABLE READ and SERIALIZABLE?"**
**A:** "REPEATABLE READ prevents non-repeatable reads (same row returns same value) but allows phantom reads (new rows can appear). SERIALIZABLE prevents both - it locks not just existing rows but the entire range, preventing any new rows from being inserted. SERIALIZABLE is the most restrictive and has the lowest concurrency, so I'd only use it for critical operations that require absolute consistency."

