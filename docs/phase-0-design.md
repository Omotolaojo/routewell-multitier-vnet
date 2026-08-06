# Phase 0 – Design Worksheet

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
- SSH only through authorized admin sources (no public SSH)
- App listens on 8080
- Database listens on MySQL 3306

| Direction | Source        | Destination | Port | Why |
|----------:|:--------------|:-----------:|:----:|:----|
| Inbound   | Internet      | Web         | 80   | Allows customers to access the dispatch application. Without it the application is unreachable. |
| Inbound   | SSH (admin) | Web         | 22   | Allows administrators to manage the web server securely. Without it, no administration is possible. |
| Inbound   | Web           | App         | 8080 | Allows web application to communicate with business logic. Removing it breaks the application. |
| Inbound   | SSH (admin) | App         | 22   | Secure administration. |
| Inbound   | App           | Database    | 3306 | Allows application to retrieve and store customer records. Removing it breaks database functionality. |
| Inbound   | SSH (admin) | Database    | 22   | Administrative access only. |
| Deny      | Internet      | Database    | Any  | Prevents direct internet exposure, satisfying compliance requirements. |
| Deny      | Web           | Database    | 3306 | Prevents bypassing the application layer. |

Notice: we do not create an "Allow VNet Any Any" rule.

---

## 2.3 Public Access Mechanism

**Choice:** SSH + Public IP on Web VM

**Justification:** The web application requires internet access, so only the web virtual machine receives a public IP address. Administrative access is provided through SSH (restricted to admin IPs, VPN, or a hardened jumpbox), eliminating the [...]

---

## 2.4 Architecture Diagram
             Internet
                 |
          Public IP (Web VM)
                 |
          +--------------+
          |   Web VM     |
          | 10.10.1.4    |
          +--------------+
                 |
             Port 8080
                 |
          +--------------+
          |   App VM     |
          | 10.10.2.4    |
          +--------------+
                 |
            Port 3306
                 |
          +--------------+
          | Database VM  |
          | 10.10.3.4    |
          +--------------+
    SSH (administration)
         |
 SSH (22) to all VMs
 
 
Network overview:

- RouteWell-VNet (10.10.0.0/16)
  - Web Subnet: 10.10.1.0/27
  - App Subnet: 10.10.2.0/26
  - DB Subnet:  10.10.3.0/28

---

## Build Plan

Create:
- Resource Group
- VNet
- Three Subnets (Web, App, DB)
- Three Linux VMs (Web, App, Database)
- Three NSGs (per subnet)
- NSG rules (as specified above)
- Associate NSGs with subnets
- SSH access configuration (VPN/jumpbox or restricted admin IPs)
- Public IP for Web VM
- Connectivity tests

---

## Connectivity Tests

Should succeed:

- Web → App
  - curl http://10.10.2.4:8080
  - or: `nc -zv 10.10.2.4 8080`

- App → Database
  - `nc -zv 10.10.3.4 3306`

Should fail:

- Web → Database
  - `nc -zv 10.10.3.4 3306`
  - Expected: Connection timed out

Take screenshots of successful and failed tests for documentation.

---

## Failure Injection Example

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

| NSG Rule                 | Worksheet Reference                          |
|:-------------------------|:---------------------------------------------|
| Internet → Web 80        | Allows public dispatch application           |
| Web → App 8080           | Allows application processing                |
| App → DB 3306            | Allows database queries                      |
| SSH → All SSH        | Secure administration                        |
| Internet → DB Deny       | Compliance requirement (no direct internet DB)|
| Web → DB Deny            | Least privilege — prevent bypassing app layer |

---

## Bash Script Tasks

This deployment script should automate:

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
