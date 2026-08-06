**CIDR Allocation Justification**

| Tier     | Hosts Today | Hosts in 6 Months | Subnet | CIDR Range   | Why |
|----------|------------:|------------------:|:------:|--------------|-----|
| Web      | 12          | 12                | /27    | 10.10.1.0/27 | Provides 32 addresses, 27 usable after Azure reserves its standard five. This gives enough capacity for the current 12 web hosts plus future frontend growth and any required infrastructure IPs. |
| App      | 20          | 40                | /26    | 10.10.2.0/26 | Offers 64 addresses, 59 usable, which supports the current application fleet and the planned doubling to around 40 hosts, while keeping the subnet size efficient. |
| Database | 6           | 6                 | /28    | 10.10.3.0/28 | Provides 16 addresses, 11 usable, enough for the current 6 database hosts and modest growth, minimizing wasted private address space. |


- Web tier: `10.10.1.0/27`  
  This subnet provides 32 addresses, of which 27 are usable after Azure reserves the standard 5. That gives enough headroom to support the current 12 web hosts plus future expansion, while also accounting for Azure’s reserved addresses.

- App tier: `10.10.2.0/26`  
  This subnet offers 64 addresses, with 59 usable. It is sized to support today’s 20 application hosts and the projected growth to around 40 hosts over the next six months, without wasting excessive address space.

- Database tier: `10.10.3.0/28`  
  This subnet includes 16 addresses, with 11 usable. That is adequate for the current six database hosts and allows limited growth while keeping the private address allocation tight and efficient.

This CIDR plan balances scalability and efficiency by allocating enough capacity for expected growth in each tier, while minimizing unused address space and preserving the network’s private address pool.
