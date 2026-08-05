**Public Access Mechanism**

**Objective**  
Provide secure public access to the RouteWell web application while keeping the Application and Database tiers private.

**Selected Public Access Mechanism**  
- Assign a single Public IP to the Web VM only.  
- Protect the Web VM with an NSG that permits HTTPS (443) and HTTP (80) from the Internet.  
- Do not assign Public IPs to the Application or Database VMs.  
- Permit traffic only from Web -> App and App -> Database.

**Design Justification**  
Using one public-facing Web VM is the simplest and most cost-effective approach for the current requirements. Because the project needs a single public web endpoint, adding components such as an Azure Load Balancer or Application Gateway would increase cost without providing proportional benefits. The Application and Database tiers remain private by design (no public IPs). Administrative SSH access is implemented as a controlled jump-host chain: administrator -> Web VM (restricted to the admin’s IP) -> App VM -> Database VM. Network Security Group rules restrict each hop so that only the immediately preceding subnet can initiate the next connection. This configuration meets the security objectives while minimizing infrastructure complexity and cost.

**Advantages**  
- Only the Web VM is exposed to the Internet.  
- The Database is never directly reachable from the Internet.  
- The Application tier remains isolated from public traffic.  
- The solution is low-cost and straightforward to operate.  
- The design follows least-privilege principles.  
- The virtual network can be expanded later without redesign.

