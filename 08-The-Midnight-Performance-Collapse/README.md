# REAL-WORLD CRISIS SCENARIO: The Midnight Performance Collapse



### THE SITUATION

* **Company:** MedicalRecords Inc. - Healthcare SaaS provider
* **Time:** 11:47 PM on a Friday night
* **My Role:** On-call DBA



* **The Alert:**

&#x09;CRITICAL: Application response time degraded

&#x09;Database server: PROD-SQL-01

&#x09;Affected: Patient Portal (5,000+ concurrent users)

&#x09;Business Impact: Hospitals cannot access patient records

&#x09;SLA Breach: Response time > 3 seconds (SLA: < 500ms)



**Phone rings - VP of Operations:**

"Our biggest client (Regional Hospital Network) is threatening to leave. Their ER doctors can't pull up patient histories. We're losing $50K per hour of downtime. FIX IT NOW!"



**What I know so far:**

* Application was running fine until 11:30 PM
* No deployments or changes scheduled
* Database server CPU at 85% (normally 40%)
* Users reporting "system freezing" and timeouts
* Development team is offline (it's Friday night)



**My mission:** Use Extended Events and Error Log analysis to diagnose and resolve the crisis before morning.



