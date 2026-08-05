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
- SSH only through Bastion
- App listens on 8080
- Database listens on MySQL 3306

| Direction | Source        | Destination | Port | Why |
|----------:|:--------------|:-----------:|:----:|:----|
| Inbound   | Internet      | Web         | 80   | Allows customers to access the dispatch application. Without it the application is unreachable. |
| Inbound   | Azure Bastion | Web         | 22   | Allows administrators to manage the web server securely. Without it, no administration is possible. |
| Inbound   | Web           | App         | 8080 | Allows web application to communicate with business logic. Removing it breaks the application. |
| Inbound   | Azure Bastion | App         | 22   | Secure administration. |
| Inbound   | App           | Database    | 3306 | Allows application to retrieve and store customer records. Removing it breaks database functionality. |
| Inbound   | Azure Bastion | Database    | 22   | Administrative access only. |
| Deny      | Internet      | Database    | Any  | Prevents direct internet exposure, satisfying compliance requirements. |
| Deny      | Web           | Database    | 3306 | Prevents bypassing the application layer. |

Notice: we do not create an "Allow VNet Any Any" rule.

---

## 2.3 Public Access Mechanism

**Choice:** Azure Bastion + Public IP on Web VM

**Justification:** The web application requires internet access, so only the web virtual machine receives a public IP address. Administrative access is provided through Azure Bastion, eliminating the need to expose SSH to the internet.

---

## 2.4 Architecture Diagram
