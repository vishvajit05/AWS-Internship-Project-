# AWS VPC Peering: Viva & Technical Defense Guide
**EWB Cloud Labs - Comprehensive Interview & Evaluation Q&A**

---

### Question 1: Why is the return route needed?
**Answer:**
IP networking is inherently bidirectional for any two-way communication protocol (such as TCP handshakes, SSH, or ICMP Echo Request / Echo Reply). 

When App-A (`10.10.2.10`) sends an ICMP Echo Request or TCP SYN packet to App-B (`10.20.1.10`), the forward route in `ewb-rt-a-private` (`10.20.0.0/16 -> pcx-xxxx`) directs the packet out across the VPC Peering connection. 

However, when App-B receives this packet, its kernel creates an Echo Reply (or TCP SYN-ACK) with destination `10.10.2.10`. AWS VPC routing operates at the subnet route table level: if `ewb-rt-b-private` does not contain an explicit route for `10.10.0.0/16 -> pcx-xxxx`, the VPC router has no valid destination for that packet and will drop it immediately (black-holing the return packet). Thus, communication fails without symmetric forward and return routes.

---

### Question 2: Why is the App-B SSH source the bastion private IP?
**Answer:**
When connecting to App-B from your laptop using SSH `ProxyJump` (e.g. `ssh -J ec2-user@<bastion_public_ip> ec2-user@10.20.1.10`), the SSH client establishes two separate, cascaded connections:
1. Connection 1: Laptop -> Bastion Public IP (originating from the laptop's public IP to Bastion port 22).
2. Connection 2: Bastion -> App-B Private IP (`10.20.1.10`).

From the network perspective of VPC B and the hypervisor hosting App-B, the incoming TCP SYN packet originates directly from the Bastion host's internal network interface in VPC A (`10.10.1.10`), not from your laptop. 

Therefore, the inbound Security Group rule on `ewb-sg-app-b` must permit TCP port 22 from `10.10.1.10/32` (the Bastion's private IP). App-B never sees, nor does it need to know, your laptop's public IP address.

---

### Question 3: Why does Active peering not guarantee a successful ping?
**Answer:**
An **Active** VPC Peering connection (`pcx-xxxx`) only establishes the underlying AWS virtual network tunnel between two VPCs. By itself, it performs neither traffic routing nor access control. 

For a `ping` (ICMP Echo) to succeed, four independent networking layers must all be properly configured:
1. **Peering Status**: Active connection.
2. **Subnet Route Tables (Both Sides)**: 
   - Requester subnet route table must have destination CIDR pointing to `pcx-xxxx`.
   - Accepter subnet route table must have return destination CIDR pointing to `pcx-xxxx`.
3. **Security Groups (Firewalls)**: 
   - The destination instance's Security Group must explicitly permit inbound `ICMP Echo Request` (Type 8, Code 0) from the source IP/CIDR. (Note: Security Groups are stateful, so outbound reply is automatically tracked).
4. **Network Access Control Lists (NACLs)**:
   - Both inbound and outbound NACLs for both subnets must allow the traffic. (Default VPC NACLs allow all traffic, but custom ACLs would require both inbound and return rules).

If any one of these (such as a missing route or missing security group rule) is not configured, the ping will fail despite the peering connection being Active.

---

### Question 4: Can VPC B use VPC A's internet gateway over peering?
**Answer:**
**No.** AWS VPC Peering is strictly **non-transitive** and does not support edge-to-edge routing.

AWS VPC Peering does not allow traffic that enters a VPC via a peering connection to exit that VPC through an Internet Gateway (IGW), NAT Gateway, Direct Connect, or VPN gateway attached to that VPC. VPC B cannot route its `0.0.0.0/0` internet traffic through VPC A's IGW (`ewb-igw-a`). 

If VPC B requires internet egress or if transitive routing across multiple VPCs and on-premises networks is required, an **AWS Transit Gateway (TGW)** or a centralized egress proxy architecture with PrivateLink / Network Load Balancer must be used instead.

---

### Bonus Technical Defense Questions (Instructor Evaluation Prep)

#### Q5: What is the rule priority in an AWS VPC Route Table?
**Answer:** 
AWS route tables always prioritize routes using the **Longest Prefix Match (LPM)** rule:
- A `/32` route is preferred over a `/24` route.
- A `/24` route is preferred over a `/16` route.
- A `/16` route is preferred over `0.0.0.0/0` (the default route).

*Example:* In `ewb-rt-a-public`, traffic destined to `10.20.0.0/16` targets `pcx-xxxx`, while traffic to the broader internet targets `0.0.0.0/0` (IGW). Because `10.20.0.0/16` is more specific than `0.0.0.0/0`, traffic intended for VPC B is cleanly routed through the peer rather than out to the internet gateway.

#### Q6: Why can overlapping VPC CIDR blocks not be peered?
**Answer:**
AWS VPC Peering enforces strict uniqueness across the paired IPv4 CIDR blocks. If VPC A and VPC B both used `10.10.0.0/16`, the virtual router would face non-deterministic destination conflicts (the local VPC route is `10.10.0.0/16 local`, so any outbound traffic to that CIDR would never leave the local VPC). AWS prevents peering requests between overlapping CIDRs at API invocation time.

#### Q7: What is the maximum MTU supported across VPC Peering within the same region?
**Answer:**
Within the same AWS Region, VPC peering connections support a Maximum Transmission Unit (MTU) of **9001 bytes (Jumbo frames)**. For inter-region VPC peering, the MTU is limited to standard Ethernet frames of **1500 bytes**.
