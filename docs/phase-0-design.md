# Phase 0 – Design Worksheet (Corrected)

## 2.1 CIDR Planning

### Step 1: Understand the requirements

| Tier     | Current Hosts | 6-Month Growth |
|----------|--------------:|---------------:|
| Web      | 12            | 12             |
| App      | 20            | 40             |
| Database | 6             | 6              |

Note: Azure reserves 5 IP addresses in every subnet.
Usable IPs = Total IPs − 5

---

### Web Tier

- Need: 12 hosts
- A /28 subnet: 16 IPs → 11 usable ❌ Not enough
- A /27 subnet: 32 IPs → 27 usable ✅ Enough

Chosen subnet: `10.10.1.0/27`

---

### App Tier

- Needs to grow to 40 hosts
- Need at least 40 usable
- A /27: 27 usable ❌
- A /26: 64 IPs → 59 usable ✅

Chosen subnet: `10.10.2.0/26`

---

### Database Tier

- Need: 6 hosts
- A /29: 8 IPs → 3 usable ❌
- A /28: 16 IPs → 11 usable ✅

Chosen subnet: `10.10.3.0/28`

---



### Final CIDR Table

| Tier     | Hosts Today | Hosts in 6 Months | Subnet | CIDR Range     | Why |
|----------|------------:|------------------:|:------:|----------------|-----|
| Web      | 12          | 12                | /27    | 10.10.1.0/27   | 27 usable IPs allow future scaling and account for Azure reserved addresses. |
| App      | 20          | 40                | /26    | 10.10.2.0/26   | 59 usable IPs accommodate expected doubling. |
| Database | 6           | 6                 | /28    | 10.10.3.0/28   | 11 usable IPs are sufficient while minimizing wasted addresses. |

---

## 2.2 NSG Rule Justification

Assume:
- Web server listens on HTTP (80)
- App listens on 8080
- Database listens on MySQL 3306
- SSH (22) is only ever sourced from the Mgmt subnet — never directly from the Internet, and never from Web into App/DB

### Inbound

| Direction | Source              | Destination | Port | Why |
|----------:|:--------------------|:-----------:|:----:|:----|
| Inbound   | Internet             | Web         | 80   | Allows customers to reach the dispatch application. Without it the application is unreachable. |
| Inbound   | Web (10.10.1.0/27)   | App         | 8080 | Allows the web tier to call business logic. Removing it breaks the application. |
| Inbound   | App (10.10.2.0/26)   | Database    | 3306 | Allows the app tier to read/write customer records. Removing it breaks database functionality. |
| Deny      | Internet              | Database    | Any  | Prevents direct internet exposure — DB should never be internet-reachable. |
| Deny      | Internet              | App         | Any  | Explicit deny for audit clarity, even though default rules already block this. |
| Deny      | Web (10.10.1.0/27)    | Database    | 3306 | Prevents bypassing the application layer — Web must never talk to DB directly. |

### Outbound (new — this was missing entirely)

| Direction | Source   | Destination | Port | Why |
|----------:|:---------|:-----------:|:----:|:----|
| Outbound  | Database | Internet    | Any  | **Deny.** DB has no legitimate reason to reach the internet; blocks exfiltration if the host is ever compromised. |
| Outbound  | App      | Internet    | Any  | Deny by default. If App needs outbound (e.g., third-party API calls, OS updates), scope this to specific destination IPs/ports rather than leaving it open to Any. |
| Outbound  | Web      | Internet    | 443  | Allow only if Web needs outbound HTTPS (e.g., package updates). Otherwise deny. |

> Azure's default NSG rules include "Allow VNet Outbound" and "Allow Internet Outbound." Left unmodified, this silently permits the DB VM to reach the internet — the outbound-deny rules above close that gap and keep the design consistent with "least privilege."

Notice: we do not create an "Allow VNet Any Any" rule.

---

## 2.3 Public Access Mechanism

**Choice:** Public IP + HTTP on Web VM only. Admin access via dedicated Mgmt subnet (Bastion or jump VM), never via direct public SSH.

**Justification:** The web application requires internet access, so only the Web VM receives a public IP address. App and Database VMs have no public IPs and are unreachable from the internet by design, not just by policy.

Administrative access does **not** SSH into the Web VM's public IP as a pivot point — that would recreate the exact failure pattern from the incident (one host able to reach resources it shouldn't). Instead:

- A dedicated **Mgmt subnet** (`10.10.4.0/29`) hosts either Azure Bastion or a hardened jump VM.
- SSH (22) into Web, App, and DB is only permitted from this Mgmt subnet's address range.
- No VM — including Web — accepts SSH directly from the Internet.

This keeps the public attack surface limited to port 80 on the Web VM, and ensures a compromised Web VM cannot be used to pivot into App or DB via SSH, since Web's NSG has no outbound SSH permission to those tiers.


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

              

--------------------------------------------------------

---

## 2.4 Architecture Diagram

```
                     Internet
                        |
                 Public IP (Web VM, :80)
                        |
                 +--------------+
                 |   Web VM     |
                 | 10.10.0.4    |
                 +--------------+
                        |
                    Port 8080
                        |
                 +--------------+
                 |   App VM     |
                 | 10.10.1.4    |
                 +--------------+
                        |
                    Port 3306
                        |
                 +--------------+
                 | Database VM  |
                 | 10.10.2.4    |
                 +--------------+

              
```

Network overview:

- RouteWell-VNet (10.10.0.0/16)
  - Web Subnet:  10.10.1.0/27
  - App Subnet:  10.10.2.0/26
  - DB Subnet:   10.10.3.0/28


---

## Build Plan

Create:
- Resource Group
- VNet
- Four Subnets (Web, App, DB, Mgmt)
- Three Linux VMs (Web, App, Database)
- Bastion host or jump VM in the Mgmt subnet
- Four NSGs (one per subnet)
- NSG inbound rules (as specified above)
- NSG outbound rules (as specified above)
- Associate NSGs with subnets
- Public IP for Web VM only
- Connectivity tests

---

## Connectivity Tests

Should succeed:

- Web → App *(run from the Web VM)*
  - `curl http://10.10.2.4:8080`
  - or: `nc -zv 10.10.2.4 8080`

- App → Database *(run from the App VM)*
  - `nc -zv 10.10.3.4 3306`


Should fail:

- Web → Database *(run from the Web VM)*
  - `nc -zv 10.10.3.4 3306`
  - Expected: Connection timed out

- Database → Internet *(run from the DB VM)*
  - `curl -m 5 https://example.com`
  - Expected: Connection timed out

- Internet → App or DB, any port *(run from outside the VNet)*
  - Expected: Connection timed out



---

## Failure Injection Example



Should fail

Web → Database

nc -zv 10.10.3.4 3306

Expected

Connection timed out.


Failure Injection Example

Delete the NSG rule:

Allow App → DB
=======
- Delete the NSG rule: Allow App → DB

Result:
- `nc -zv 10.10.3.4 3306`
  Output: Connection timed out

### Investigation

1. Check existing rules:
   - `az network nsg rule list --resource-group <rg> --nsg-name <nsg-name>`
2. Observe the missing rule.
3. Recreate the rule (using `az network nsg rule create ...` or your automation).
4. Retest connectivity.
5. Confirm success.

---

## README Mapping

| NSG Rule                          | Worksheet Reference                                  |
|:-----------------------------------|:------------------------------------------------------|
| Internet → Web 80                  | Allows public dispatch application                     |
| Mgmt → Web / App / DB 22           | Secure administration via dedicated jump/Bastion subnet |
| Web → App 8080                     | Allows application processing                          |
| App → DB 3306                      | Allows database queries                                |
| Internet → DB Deny                 | Compliance requirement (no direct internet DB)         |
| Internet → App Deny                | Explicit deny for audit clarity                        |
| Web → DB Deny                      | Least privilege — prevents bypassing the app layer      |
| DB → Internet Deny (outbound)      | Prevents exfiltration if DB host is compromised         |
| App → Internet Deny (outbound)     | Least privilege — no unscoped outbound from app tier    |

---

## Bash Script Tasks

The deployment script will automate:

1. Create Resource Group
2. Create VNet
3. Create Web subnet
4. Create App subnet
5. Create DB subnet
6. Create Mgmt subnet
7. Create NSGs (Web, App, DB, Mgmt)
8. Create NSG inbound rules
9. Create NSG outbound rules
10. Associate NSGs with subnets
11. Create Public IP (Web only)
12. Create Web VM
13. Create App VM
14. Create DB VM
15. Deploy Bastion or jump VM in Mgmt subnet
16. Run connectivity tests and capture output
