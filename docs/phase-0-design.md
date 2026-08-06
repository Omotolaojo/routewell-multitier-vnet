Phase 0 – Design Worksheet

2.1 CIDR Planning

Step 1: Understand the requirements

Tier	Current Hosts	6-Month Growth
Web	12	12
App	20	40
Database	6	6

Remember:

Azure reserves 5 IP addresses in every subnet.

Usable IPs = Total IPs − 5

⸻

Web Tier

Need:

12 hosts

A /28 subnet

16 IPs

11 usable

❌ Not enough

A /27 subnet

32 IPs

27 usable

✅ Enough

Chosen subnet:

10.10.1.0/27

⸻

App Tier

Needs to grow to

40 hosts

Need at least

40 usable

A /27

27 usable

❌

A /26

64 IPs

59 usable

✅

Chosen subnet

10.10.2.0/26



Database Tier

Need

6 hosts

A /29

8 IPs

3 usable

❌

A /28

16 IPs

11 usable

✅

Chosen subnet

10.10.3.0/28



Final CIDR Table

| Tier     | Hosts Today | Hosts in 6 Months | Subnet | CIDR Range   | Why |
|----------|------------:|------------------:|:------:|--------------|-----|
| Web      | 12          | 12                | /27    | 10.10.1.0/27 | 27 usable IPs allow future scaling and Azure reserved addresses. |
| App      | 20          | 40                | /26    | 10.10.2.0/26 | 59 usable IPs accommodate expected doubling. |
| Database | 6           | 6                 | /28    | 10.10.3.0/28 | 11 usable IPs are sufficient while minimizing wasted addresses. |



2.2 NSG Rule Justification

Assume:

* Web server listens on HTTP (80)
* SSH only through Bastion
* App listens on 8080
* Database listens on MySQL 3306

Direction	Source	Destination	Port	Why
Inbound	Internet	Web	80	Allows customers to access the dispatch application. Without it the application is unreachable.
Inbound	Azure Bastion	Web	22	Allows administrators to manage the web server securely. Without it no administration is possible.
Inbound	Web	App	8080	Allows web application to communicate with business logic. Removing it breaks the application.
Inbound	Azure Bastion	App	22	Secure administration.
Inbound	App	Database	3306	Allows application to retrieve and store customer records. Removing it breaks all database functionality.
Inbound	Azure Bastion	Database	22	Administrative access only.
Deny	Internet	Database	Any	Prevents direct internet exposure, satisfying compliance requirements.
Deny	Web	Database	3306	Prevents bypassing the application layer.

Notice we do not create “Allow VNet Any Any”.



2.3 Public Access Mechanism

Choice

Azure Bastion + Public IP on Web VM

Justification

The web application requires internet access, so only the web virtual machine receives a public IP address. Administrative access is provided through Azure Bastion, eliminating the need to expose SSH (port 22) to the internet. The application and database virtual machines remain private and are accessible only through controlled network security group rules. This design satisfies the compliance requirement that the database is never directly reachable from the internet while minimizing infrastructure cost.



2.4 Architecture Diagram

                 Internet
                     |
              Public IP
                     |
              +--------------+
              |   Web VM     |
              |10.10.1.4     |
              +--------------+
                     |
                 Port 8080
                     |
              +--------------+
              |   App VM     |
              |10.10.2.4     |
              +--------------+
                     |
                Port 3306
                     |
              +--------------+
              | Database VM  |
              |10.10.3.4     |
              +--------------+
        
                     |
     SSH (22) to all VMs
--------------------------------------------------------
              RouteWell-VNet (10.10.0.0/16)
Web Subnet
10.10.1.0/27
App Subnet
10.10.2.0/26
DB Subnet
10.10.3.0/28
--------------------------------------------------------



Build Plan

Create:

* Resource Group
* VNet
* Three Subnets
* Three Linux VMs
* Three NSGs
* Bastion
* Public IP for Web VM
* Connectivity tests



Connectivity Tests

Should succeed

Web → App

curl http://10.10.2.4:8080

or

nc -zv 10.10.2.4 8080



App → Database

nc -zv 10.10.3.4 3306


Should fail

Web → Database

nc -zv 10.10.3.4 3306

Expected

Connection timed out.


Failure Injection Example

Delete the NSG rule:

Allow App → DB

Result:

nc -zv 10.10.3.4 3306
Connection timed out
 

Investigation

Check:

az network nsg rule list

  ↓

Rule missing

  ↓

Recreate rule

  ↓

Retest

  ↓

Success


README Mapping

NSG Rule	Worksheet Reference
Internet → Web 80	Allows public dispatch application
Web → App 8080	Allows application processing
App → DB 3306	Allows database queries
Bastion → All SSH	Secure administration
Internet → DB Deny	Compliance requirement
Web → DB Deny	Least privilege


Bash Script Tasks

this deployment script should automate:

1. Create Resource Group
2. Create VNet
3. Create Web subnet
4. Create App subnet
5. Create DB subnet
6. Create NSGs
7. Create NSG rules
8. Associate NSGs with subnets
9. Create Public IP
10. Create Web VM
11. Create App VM
12. Create DB VM

  