# NSG Rule Justification

## Objective

Network Security Groups (NSGs) enforce least privilege by permitting only the traffic required for the application to operate.

## Implemented NSG Rules

| Rule | Source | Destination | Port | Action | Purpose | Impact if removed |
|------|--------|-------------|------|--------|---------|-------------------|
| Internet -> Web | Internet | Web Subnet | 80, 443 | Allow | Enables customers and dispatch staff to access the public web application. | The website becomes inaccessible. |
| Admin -> Web | Admin IP | Web VM | 22 | Allow | Allows administrators to manage the Web VM; it is the only externally reachable management point. | Admins cannot SSH into any VM, since App and Database require jumping through Web. |
| Web -> App | Web Subnet | App Subnet | 8080 | Allow | Permits the web tier to call the application tier. | The web app cannot process requests. |
| Web -> App (SSH) | Web Subnet | App VM | 22 | Allow | Enables admins to SSH to App VM via Web as a jump host (App has no public IP). | Admins lose SSH access to the App VM. |
| App -> Database | App Subnet | Database Subnet | 5432 | Allow | Lets the application read/write PostgreSQL data. | The application cannot access its database; system fails. |
| App -> Database (SSH) | App Subnet | Database VM | 22 | Allow | Enables admin SSH to Database VM via App VM (jump host chain). | Admins cannot SSH into the Database VM. |
| Deny other VNet traffic | VirtualNetwork | App Subnet, Database Subnet | Any | Deny | Overrides Azure's default `AllowVnetInBound` to prevent other subnets (e.g., Web) from directly reaching App/Database and bypassing tier controls. | Web could reach Database directly, breaking the intended tier isolation. |
| (No rule needed) Internet -> Database | Internet | Database Subnet | Any | N/A | Database VMs have no public IPs, so there is no Internet route to them; network design enforces this. | N/A — enforced by design rather than an NSG rule. |

## Changes since the Phase 0 plan

Phase 0 assumed the administrator IP could SSH directly to App and Database VMs. In reality, App and Database were intentionally assigned no public IPs. SSH was redesigned as a jump-host chain: Admin -> Web -> App -> Database. The table above reflects what was built and validated.

During connectivity testing (see `incident-report.md`), Azure’s default `AllowVnetInBound` allowed Web-to-Database traffic. We resolved this by adding explicit deny rules on both the App and Database NSGs.

## Design Decisions

- Each subnet has its own NSG so tier-specific policies can be applied independently.
- Only necessary application traffic is allowed between tiers; administrative SSH uses a jump-host chain rather than direct access.
- The Database subnet is the most restrictive: it contains sensitive data and includes an explicit deny to close Azure’s default permissive behavior.
- The design adheres to least privilege by denying all unnecessary communication, including flows Azure would otherwise permit by default.

