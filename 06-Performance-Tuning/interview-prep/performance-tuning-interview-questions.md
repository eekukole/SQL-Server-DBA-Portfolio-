\# Performance Tuning - Interview Questions \& Answers



\## QUESTION 1: "Explain the different types of waits in SQL Server and what they indicate."



\*\*Answer:\*\*

"SQL Server wait statistics tell us exactly what the server is waiting for, which is the foundation of performance troubleshooting.



The most common wait types I monitor are:



\*\*PAGEIOLATCH waits\*\* indicate SQL Server is waiting to read data pages from disk into memory. This usually means either slow disk I/O or insufficient memory. Solutions include faster storage, adding memory, or optimizing queries to read fewer pages.



\*\*LCK\_M waits\*\* (like LCK\_M\_S for shared locks or LCK\_M\_X for exclusive locks) indicate blocking - one session waiting for another to release a lock. I'd investigate the blocking chain using sys.dm\_exec\_requests to find the root blocker and determine if it's a long-running transaction or poor application design.



\*\*CXPACKET waits\*\* relate to parallelism. If it's less than 50% of total waits, it's just parallelism working normally. If higher, it might indicate uneven data distribution or improper indexing causing some parallel threads to wait for others.



\*\*WRITELOG waits\*\* mean SQL Server is waiting to write to the transaction log. This points to slow log disk performance - the solution is faster storage for the log file.



\*\*RESOURCE\_SEMAPHORE waits\*\* indicate memory pressure - queries waiting for memory grants. Solutions include adding memory, optimizing queries to use less memory, or reducing MAXDOP.



I always start troubleshooting by querying sys.dm\_os\_wait\_stats filtered for non-benign waits, ordered by wait\_time\_ms descending, to see which wait type is consuming the most time."



\---



\## QUESTION 2: "What's the difference between blocking and deadlocking? How do you resolve each?"



\*\*Answer:\*\*

"Blocking and deadlocking are both concurrency issues but fundamentally different.



\*\*Blocking\*\* occurs when Session A holds a lock and Session B waits for it. This is temporary - Session B will eventually get the lock when Session A commits or rolls back. A certain amount of blocking is normal and expected in any multi-user database. I investigate blocking when:

\- Wait time exceeds 30 seconds

\- It's causing application timeouts

\- It's affecting critical business processes



To resolve blocking, I:

1\. Query sys.dm\_exec\_requests to find the blocking chain

2\. Identify the root blocker (blocking\_session\_id <> 0 but itself isn't blocked)

3\. Check what the blocker is doing using sys.dm\_exec\_sql\_text

4\. If it's a long-running query, work with the application team to optimize it

5\. As a last resort during production outages, kill the blocking session (KILL command)



\*\*Deadlocking\*\* is different - it's a circular dependency where Session A waits for Session B AND Session B waits for Session A. This will never resolve on its own. SQL Server detects deadlocks using a lock monitor thread every 5 seconds and kills one session (the deadlock victim) - typically the one that's made the fewest changes.



To handle deadlocks, I:

1\. Enable Trace Flag 1222 to capture deadlock graphs in the error log

2\. Review the deadlock graph to understand which resources were involved

3\. Look for application patterns causing the deadlock (usually accessing tables in different orders)

4\. Fix the root cause - make all code access tables in the same order

5\. Consider using SNAPSHOT isolation to avoid read locks

6\. Use SET DEADLOCK\_PRIORITY to control which session becomes the victim if needed



Prevention is key for both: keep transactions short, use appropriate isolation levels, and ensure good indexing so locks are held briefly."



\---



\## QUESTION 3: "Explain the four isolation levels and when you'd use each one."



\*\*Answer:\*\*

"SQL Server has four isolation levels that control how transactions see changes made by other concurrent transactions:



\*\*READ UNCOMMITTED\*\* (lowest isolation) allows dirty reads - you can see uncommitted changes from other transactions. I'd only use this for reports where approximate data is acceptable and performance is critical, like a dashboard showing 'approximately 10,000 active users.' Never for transactional data because you might read data that gets rolled back.



\*\*READ COMMITTED\*\* (SQL Server default) prevents dirty reads but allows non-repeatable reads. If you read a row twice in the same transaction, you might get different values if another transaction modified and committed between your reads. This is appropriate for most OLTP applications - it balances consistency with concurrency.



\*\*REPEATABLE READ\*\* prevents dirty reads AND non-repeatable reads by holding shared locks until transaction end. However, it still allows phantom reads - new rows can appear. I use this for financial calculations where values shouldn't change mid-transaction, like bank transfers where the account balance must remain stable during the transfer.



\*\*SERIALIZABLE\*\* (highest isolation) prevents dirty reads, non-repeatable reads, AND phantom reads by locking not just rows but entire ranges. This gives the highest consistency but lowest concurrency. I use it for critical operations requiring absolute consistency, like month-end financial closing or when regulatory compliance demands it.



There's also \*\*SNAPSHOT isolation\*\*, which uses row versioning to avoid read locks entirely - readers don't block writers and vice versa. I'd recommend this for applications with heavy read/write conflicts, though it requires tempdb space for row versions.



The key is understanding the trade-off: higher isolation = more consistency but lower concurrency. Choose based on your application's consistency requirements and acceptable performance impact."



\---



\## QUESTION 4: "How do you troubleshoot a slow query?"



\*\*Answer:\*\*

"I follow a systematic approach:



\*\*Step 1: Capture the execution plan\*\* (Ctrl+M in SSMS). The execution plan shows exactly what SQL Server is doing. I look for:

\- Table scans or index scans on large tables (should be seeks)

\- Key lookups or RID lookups (indicates missing covering index)

\- Hash matches or sort operators (expensive operations)

\- Yellow warning icons (missing stats, implicit conversions, etc.)

\- Thick arrows (large row counts flowing between operators)

\- High-cost operators (look at percentage)



\*\*Step 2: Check statistics with SET STATISTICS IO ON and TIME ON.\*\* This shows:

\- Logical reads (pages read from memory)

\- Physical reads (pages read from disk)

\- CPU time vs elapsed time



High logical reads mean the query is touching too many pages. Physical reads mean data isn't cached. If CPU time is much less than elapsed time, the query is waiting (check wait stats).



\*\*Step 3: Query sys.dm\_exec\_query\_stats\*\* to see historical performance:

\- How many times has this executed?

\- What's the average CPU time?

\- What's the average logical reads?

\- Are there parameter sniffing issues (big variance in execution times)?



\*\*Step 4: Check for missing indexes\*\* using sys.dm\_db\_missing\_index\_details. SQL Server recommends indexes based on actual query patterns.



\*\*Step 5: Look for anti-patterns:\*\*

\- SELECT \* instead of specific columns

\- Functions on indexed columns (prevents index usage)

\- Implicit conversions (varchar to int)

\- Cursors or loops that could be set-based operations



\*\*Step 6: Fix the root cause:\*\*

\- Add appropriate indexes

\- Rewrite query to be set-based

\- Update statistics if stale

\- Consider partitioning for very large tables



\*\*Step 7: Verify improvement\*\* by comparing before/after execution plans and statistics.



The key is execution plans - they tell you exactly what SQL Server is doing and where time is spent."



\---



\## QUESTION 5: "What tools do you use for performance monitoring?"



\*\*Answer:\*\*

"I use a combination of built-in SQL Server tools:



\*\*DMVs (Dynamic Management Views)\*\* are my primary troubleshooting tool:

\- sys.dm\_os\_wait\_stats - Overall wait statistics

\- sys.dm\_exec\_requests - Currently running queries

\- sys.dm\_exec\_query\_stats - Historical query performance

\- sys.dm\_db\_index\_usage\_stats - Index usage patterns

\- sys.dm\_db\_missing\_index\_details - Index recommendations

\- sys.dm\_io\_virtual\_file\_stats - File-level I/O statistics



\*\*Activity Monitor\*\* (Ctrl+Alt+A) gives a real-time dashboard showing CPU usage, waiting tasks, processes, resource waits, and expensive queries. It's great for quick health checks.



\*\*SQL Server Profiler\*\* or \*\*Extended Events\*\* for capturing specific events. Extended Events is lighter-weight and recommended for production. I use it to capture:

\- Queries exceeding a duration threshold

\- Deadlocks

\- Long-running transactions

\- Specific wait types



\*\*Execution Plans\*\* for query tuning. I always capture actual execution plans, not estimated, because estimated rows vs actual rows mismatches indicate stale statistics.



\*\*Performance counters\*\* at the OS level:

\- % Processor Time

\- Disk Avg. sec/Read and Avg. sec/Write

\- Available memory

\- SQL-specific counters like Page Life Expectancy and Buffer Cache Hit Ratio



\*\*For proactive monitoring\*\*, I maintain a baseline table that captures:

\- Wait statistics snapshots every hour

\- Top resource-consuming queries daily

\- Index fragmentation weekly

\- Database growth trends monthly



I query these baselines to spot trends before they become critical - like CPU gradually increasing or a specific wait type growing over time.



The key is not just collecting data but knowing which tool answers which question. For 'why is this slow right now?' - DMVs and Activity Monitor. For 'why was this slow yesterday?' - query stats and historical baselines. For 'why is this specific query slow?' - execution plans."



\---



\## QUESTION 6: "Explain lock escalation and when it becomes a problem."



\*\*Answer:\*\*

"Lock escalation is SQL Server's mechanism to reduce memory overhead by converting many fine-grained locks (row or page locks) into fewer coarse-grained locks (table locks).



By default, SQL Server escalates to a table lock when a single statement acquires more than 5,000 locks on a table. This is normally beneficial because:

\- Reduces lock manager memory consumption

\- Reduces overhead of managing thousands of individual locks



However, escalation can cause problems:

1\. \*\*Increased blocking\*\* - a table lock blocks ALL other users from that table, not just specific rows

2\. \*\*Deadlocks\*\* - escalation changes the lock granularity mid-transaction, potentially causing deadlocks

3\. \*\*Application timeouts\*\* - users waiting for table lock to release



I investigate lock escalation when:

\- Applications report blocking issues

\- Deadlocks occur during bulk operations

\- Lock escalation events appear in Extended Events



Solutions:

1\. \*\*Partition large tables\*\* - escalation happens per partition, not per table

2\. \*\*Use ROWLOCK hint\*\* - forces row-level locks, but use carefully as it can increase memory pressure

3\. \*\*Disable escalation\*\* - ALTER TABLE ... SET (LOCK\_ESCALATION = DISABLE), but monitor lock memory

4\. \*\*Break large operations into smaller batches\*\* - update 1000 rows at a time instead of 1 million

5\. \*\*Use SNAPSHOT isolation\*\* - readers don't acquire locks so escalation doesn't block them



Monitor lock escalation using:

\- Extended Events (lock\_escalation event)

\- sys.dm\_tran\_locks during large operations

\- Performance counter: SQL Server Locks\\\\Lock Escalations/sec



The goal isn't to eliminate escalation entirely - it serves a purpose. The goal is to prevent it from causing blocking that impacts users."



\---



\## QUESTION 7: "How do you handle a production performance crisis at 2 AM?"



\*\*Answer:\*\*

"First, I stay calm and follow a systematic approach. Panic leads to mistakes.



\*\*Immediate Assessment (2-3 minutes):\*\*

1\. Is the server up? Can I connect?

2\. Quick wait stats check - what's the top wait type?

3\. Are there blocking chains? How many sessions blocked?

4\. CPU and memory usage?



This tells me the problem category: blocking, CPU pressure, I/O bottleneck, or memory pressure.



\*\*If Blocking:\*\*

\- Identify blocking chain using sys.dm\_exec\_requests

\- Check if root blocker is an application transaction (common) or runaway query

\- Contact application team if possible

\- If business-critical and blocker is non-essential: KILL the blocking session after documenting what it was doing

\- Communicate impact: 'We killed session X doing Y to restore service. Transaction was rolled back.'



\*\*If CPU Spike:\*\*

\- Find top CPU queries from sys.dm\_exec\_query\_stats

\- Check if they're essential business operations or something abnormal

\- If non-essential: Kill them

\- If essential but inefficient: Contact development team

\- Consider temporarily reducing MAXDOP



\*\*If I/O Bottleneck:\*\*

\- Check which files are slow (sys.dm\_io\_virtual\_file\_stats)

\- Find I/O intensive queries

\- Check for missing indexes that could reduce I/O

\- Kill non-essential queries with high logical reads



\*\*Communication:\*\*

\- Notify stakeholders immediately: 'Database performance degraded, investigating'

\- Update every 10 minutes: 'Found root cause, implementing fix'

\- Final update: 'Resolved, normal operations restored, post-mortem tomorrow'



\*\*Documentation:\*\*

\- Screenshot everything: wait stats, blocking chains, expensive queries

\- Capture execution plans of killed queries

\- Note timeline: when detected, actions taken, when resolved

\- Save to post-incident review folder



\*\*Post-Resolution:\*\*

\- Monitor for 30 minutes to ensure stability

\- Document root cause

\- Schedule post-mortem with team

\- Create prevent action plan



\*\*Key principle:\*\* Fix it now, understand it later. At 2 AM, restore service first, then find permanent fix the next day.



I'd also mention that preventing 2 AM calls is better than handling them - good monitoring with alerts for wait time thresholds, blocking duration, CPU spikes, and I/O latency catches issues before users notice."



\---



\## QUESTION 8: "What's the difference between a table scan, index scan, and index seek? Which is best?"



\*\*Answer:\*\*

"These are execution plan operators showing how SQL Server accesses data:



\*\*Table Scan (or Clustered Index Scan):\*\*

\- SQL Server reads EVERY row in the table

\- Used when:

&#x20; \* No WHERE clause (SELECT \* FROM table)

&#x20; \* WHERE clause on non-indexed column

&#x20; \* Query needs most/all rows anyway

\- Cost: Proportional to table size (100K rows = reads all 100K)

\- Generally bad for large tables with selective queries

\- Can be okay for small tables (<1000 rows) or if you actually need all rows



\*\*Index Scan:\*\*

\- SQL Server reads EVERY row in a nonclustered index

\- Similar to table scan but on an index

\- Used when:

&#x20; \* WHERE clause on indexed column but not selective enough

&#x20; \* OR condition that can't use seeks

&#x20; \* Query needs most index rows

\- Still expensive on large indexes

\- Better than table scan if index is smaller than table



\*\*Index Seek:\*\*

\- SQL Server navigates the B-tree directly to specific rows

\- Used when:

&#x20; \* WHERE clause matches index key with = or specific range

&#x20; \* Index statistics show query will return small % of rows

\- Cost: Logarithmic (seek time) + reading matching rows

\- Best performance - this is the goal

\- On 1 million row table, seek might read 10 rows vs scan reading all 1 million



\*\*Which is best depends on selectivity:\*\*

\- Seeking 1 row from 1 million → Seek is best

\- Getting 10% of rows → Seek is probably best

\- Getting 50%+ of rows → Scan might be more efficient (SQL Server knows this)

\- Getting all rows → Scan is definitely better (seeking each row would be slower)



\*\*In execution plans I look for:\*\*

\- Seeks on large tables with selective WHERE clauses = Good

\- Scans on large tables with selective WHERE clauses = Missing index

\- Thick arrow from scan operator = Too many rows, probably needs index



\*\*Key Lookup caveat:\*\*

An index seek followed by key lookup can be expensive if returning many rows. This indicates a non-covering index - adding INCLUDE columns can eliminate key lookups and improve performance.



The optimizer usually chooses correctly between seek and scan based on statistics. If it's choosing scan when you expect seek, check if statistics are stale (UPDATE STATISTICS) or if parameter sniffing is causing issues."



\---



\## QUESTION 9: "How would you optimize a query that's doing a lot of key lookups?"



\*\*Answer:\*\*

"Key lookups (also called RID lookups for heaps) occur when a nonclustered index has the search column but not all the SELECT columns, forcing SQL Server to jump back to the clustered index to get the remaining columns.



For example:

```sql

CREATE INDEX IX\_City ON Customers(City);

SELECT FirstName, LastName, Email FROM Customers WHERE City = 'Chicago';

```



Execution plan shows: Index Seek on IX\_City → Key Lookup (get FirstName, LastName, Email) → Nested Loops Join



Each key lookup is an additional I/O operation. If returning 10,000 rows, that's 10,000 key lookups!



\*\*Solution 1: Create a covering index\*\*

```sql

CREATE INDEX IX\_City\_Covering ON Customers(City) 

INCLUDE (FirstName, LastName, Email);

```



Now the index contains ALL columns needed - no key lookup required. The plan becomes just: Index Seek on IX\_City\_Covering.



\*\*Solution 2: Add to existing index\*\*

If the query is critical and the current index isn't heavily used:

```sql

DROP INDEX IX\_City ON Customers;

CREATE INDEX IX\_City ON Customers(City) 

INCLUDE (FirstName, LastName, Email);

```



\*\*When NOT to add INCLUDE columns:\*\*

\- If SELECT includes many columns (would make index too wide)

\- If column data is very wide (varchar(max), nvarchar(max))

\- If table has heavy INSERT/UPDATE/DELETE (every included column adds overhead)



\*\*Solution 3: If many columns needed\*\*

Consider if SELECT \* is really necessary. Often application only uses a few columns but queries for all. Work with developers to SELECT only needed columns.



\*\*Solution 4: Read/Write ratio check\*\*

Query sys.dm\_db\_index\_usage\_stats to check read vs write ratio:

\- If 100 reads, 1 write → Covering index worth it

\- If 10 reads, 100 writes → Covering index might hurt INSERT/UPDATE performance



\*\*Verification:\*\*

After creating covering index:

1\. Capture new execution plan - key lookup should disappear

2\. SET STATISTICS IO ON - logical reads should decrease significantly

3\. Compare before/after execution times

4\. Monitor index usage stats to ensure it's being used



The key is understanding that key lookups aren't always bad - if returning 5 rows out of 1 million, 5 key lookups is negligible. But returning 50,000 rows with 50,000 key lookups is a major performance issue that a covering index would solve."



\---



\## QUESTION 10: "Describe your approach to creating a performance baseline."



\*\*Answer:\*\*

"A performance baseline is critical because you can't improve what you don't measure. Without a baseline, you can't tell if performance is degrading or if today's problem is actually normal behavior.



\*\*My approach:\*\*



\*\*Step 1: Identify key metrics to baseline\*\*

\- Wait statistics (top wait types and cumulative wait time)

\- CPU utilization (SQL Server and OS level)

\- Memory metrics (Page Life Expectancy, Buffer Cache Hit Ratio)

\- I/O statistics (reads/writes per second, average latency)

\- Top resource-consuming queries (CPU, I/O, duration)

\- Blocking frequency and duration

\- Database growth rates

\- Index fragmentation levels



\*\*Step 2: Create baseline tables\*\*

```sql

CREATE TABLE PerformanceBaseline\_Waits (

&#x20;   CaptureTime DATETIME,

&#x20;   WaitType VARCHAR(100),

&#x20;   WaitTime\_MS BIGINT,

&#x20;   WaitCount BIGINT

);



CREATE TABLE PerformanceBaseline\_Queries (

&#x20;   CaptureTime DATETIME,

&#x20;   QueryHash BINARY(8),

&#x20;   QueryText VARCHAR(MAX),

&#x20;   ExecutionCount INT,

&#x20;   AvgCPU\_MS BIGINT,

&#x20;   AvgReads BIGINT

);

```



\*\*Step 3: Establish capture schedule\*\*

\- Every 15 minutes: Wait stats snapshot

\- Hourly: Top queries by CPU, I/O, duration

\- Daily: Index usage stats, fragmentation

\- Weekly: Database sizes, growth trends



\*\*Step 4: Capture during different business cycles\*\*

\- Peak hours (morning, lunch, end of day)

\- Off-peak hours (nights, weekends)

\- Month-end processing (if applicable)

\- Year-end processing

\- After major releases



This accounts for normal variation - Monday morning looks different from Sunday 3 AM.



\*\*Step 5: Analysis and alerting\*\*

Create views that compare current metrics to baseline:

```sql

\-- Alert if current wait time is 3x baseline

SELECT 

&#x20;   'Wait time anomaly' AS Alert,

&#x20;   wait\_type

FROM sys.dm\_os\_wait\_stats current

INNER JOIN PerformanceBaseline\_Waits baseline 

&#x20;   ON current.wait\_type = baseline.wait\_type

WHERE current.wait\_time\_ms > baseline.WaitTime\_MS \* 3;

```



\*\*Step 6: Baseline maintenance\*\*

\- Refresh baselines quarterly to account for business growth

\- After major application changes, establish new baseline

\- Archive old baselines for year-over-year comparisons

\- Document what's "normal" for each metric



\*\*Step 7: Use baselines for capacity planning\*\*

\- If CPU trending up 5% per quarter, project when you'll hit 80%

\- If database growing 10GB/month, project storage needs

\- If query volume increasing, plan for hardware upgrades



\*\*Real-world example:\*\*

At my previous position, we captured baselines before Black Friday. During Black Friday, we saw queries taking 3x longer than baseline but wait stats showed this was due to 10x query volume, not a performance regression. Without the baseline, we would have wasted time troubleshooting queries that were actually performing fine - the issue was simply unprecedented load requiring additional servers, not query optimization.



The key is: baseline during normal operations, then use it to detect abnormal conditions quickly."



\---



\## BONUS QUESTION: "Walk me through investigating a deadlock."



\*\*Answer:\*\*

"Deadlock investigation is detective work - you need the deadlock graph to understand what happened.



\*\*Step 1: Enable deadlock capture (if not already enabled)\*\*

```sql

DBCC TRACEON(1222, -1);  -- Logs deadlocks to error log

```



Or create an Extended Events session to capture deadlock\_graph events.



\*\*Step 2: When deadlock occurs, get the graph\*\*

```sql

EXEC sp\_readerrorlog 0, 1, 'deadlock';

```



The deadlock graph is XML showing:

\- Which sessions were involved (SPIDs)

\- What resources they were trying to lock

\- Which session was chosen as victim

\- Full T-SQL of both queries



\*\*Step 3: Analyze the graph\*\*

Look for:

\- \*\*Resource list\*\*: Which tables/rows were involved

\- \*\*Process list\*\*: What each session was trying to do

\- \*\*Lock sequence\*\*: Session A locked Table1 then tried Table2; Session B locked Table2 then tried Table1



Classic example:

Session 1: BEGIN TRAN; UPDATE Customers...; UPDATE Orders...;

Session 2: BEGIN TRAN; UPDATE Orders...; UPDATE Customers...;



Both sessions locked different tables first, then tried to lock what the other held - circular dependency.



\*\*Step 4: Identify the pattern\*\*

\- Same application module causing it repeatedly?

\- Specific time of day (batch processing overlap)?

\- Recent code deployment?

\- Missing indexes causing escalation?



\*\*Step 5: Root cause fixes\*\*

\- \*\*Access tables in same order\*\*: Enforce Customers always locked before Orders

\- \*\*Keep transactions short\*\*: Commit/rollback quickly

\- \*\*Use appropriate isolation levels\*\*: Consider SNAPSHOT to avoid read locks

\- \*\*Reduce lock footprint\*\*: Index WHERE clauses so fewer rows locked

\- \*\*Batch large operations\*\*: Update 1000 rows at a time, commit, repeat



\*\*Step 6: Temporary workaround\*\*

If can't fix immediately, use SET DEADLOCK\_PRIORITY:

\- Set batch job to LOW priority (will be victim)

\- Set user transactions to NORMAL (will survive)

\- This doesn't prevent deadlock but controls which process is killed



\*\*Step 7: Monitoring\*\*

Create Extended Events session to track deadlock frequency:

\- If increasing over time → Application problem or growing data

\- If only during specific operations → Focus tuning there



\*\*Step 8: Application retry logic\*\*

Work with developers to implement:

```csharp

try {

&#x20;   // Execute transaction

} catch (SqlException ex) {

&#x20;   if (ex.Number == 1205) {  // Deadlock victim

&#x20;       // Wait random interval, retry up to 3 times

&#x20;   }

}

```



\*\*Real example:\*\*

We had deadlocks between order processing and inventory updates. Deadlock graph showed both processes accessed Products table then OrderItems table, but in different orders. Fix: Changed inventory update stored procedure to match order processing - always lock Products first, then OrderItems. Deadlocks dropped from 50/day to zero.



The key is deadlocks are always caused by lock ordering - either fix the order or accept occasional deadlocks and implement retry logic."

