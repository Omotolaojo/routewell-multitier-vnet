# Incident Report

## Date
2026-08-11

## Summary
A security review identified a network design weakness after a near-miss incident where a contractor-accessible endpoint could reach the database tier. The investigation confirmed that the original flat network architecture permitted unauthorized lateral access within the virtual network.

## Background
RouteWell initially deployed the web, application, and database systems in a single flat VNet. During validation, a contractor machine on the same network was able to reach the database host, demonstrating insufficient subnet segmentation and access control.

## Incident Details
- The Application and Database tiers were on a shared VNet without effective subnet isolation.
- Azure's default `AllowVnetInBound` behavior permitted intra-VNet traffic unless explicitly blocked.
- The database tier became reachable from internal endpoints that should have been restricted.
- External SSH attempts to non-Web public IPs failed with exit code 255, confirming that only the web tier was externally reachable after mitigation.

## Impact
- Exposure of the database tier to unauthorized internal network traffic.
- Increased risk of data access or manipulation from improperly segmented hosts.
- A failure of the network security design to enforce least-privilege boundaries.

## Root Cause
- The network was effectively flat for the application and database workloads.
- NSG rules did not explicitly deny broad VirtualNetwork inbound traffic for App and Database subnets.
- The design relied on public IP assignment rather than explicit subnet-to-subnet controls.

## Remediation
- Assigned a Public IP only to the Web VM.
- Kept the App and Database VMs on private subnets with no public IPs.
- Applied dedicated NSGs to each subnet:
  - `web-nsg`: allows Internet HTTP/HTTPS and SSH only from the administrator IP.
  - `app-nsg`: allows inbound 8080 and SSH only from the Web subnet; denies all other VirtualNetwork traffic.
  - `db-nsg`: allows inbound PostgreSQL (5432) only from the App subnet and SSH only from the App subnet; denies all other VirtualNetwork traffic.
- Added explicit deny rules to close Azure’s default permissive intra-VNet behavior.

## Verification
- Confirmed Web-to-App connectivity using `az vm run-command invoke` with a TCP test to port 8080.
- Observed SSH connection failures (`exit code 255`) to public IPs outside the Web tier, demonstrating that private tiers are not directly reachable.

## Lessons Learned
- Default Azure VNet rules are not sufficient to enforce tier isolation.
- Explicit NSG allow/deny rules are required for secure subnet segmentation.
- Public exposure should be limited to the minimum necessary endpoint.
- Jump-host administration must be tightly controlled and validated.

## Recommendations
- Continue enforcing subnet-specific NSGs with explicit allow and deny rules.
- Limit public IP exposure to only the Web tier.
- Regularly test connectivity and policy enforcement with automated validation scripts.
- Audit Azure NSGs and VNet configuration periodically to ensure no unintended access is allowed.
