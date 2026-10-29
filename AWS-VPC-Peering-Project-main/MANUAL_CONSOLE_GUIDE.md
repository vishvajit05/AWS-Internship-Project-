# AWS VPC Peering - Complete Step-by-Step AWS Console Walkthrough Guide
**EWB Cloud Labs: Student Project Workbook**  
*Project Title: Connect Two VPCs & Prove Private Connectivity*

---

## Table of Contents
1. [Overview & Architecture Summary](#1-overview--architecture-summary)
2. [Phase 1: Pre-requisites & Key Pair Creation](#phase-1-pre-requisites--key-pair-creation)
3. [Phase 2: Build VPC A (Public & Private Subnets + IGW)](#phase-2-build-vpc-a)
4. [Phase 3: Build VPC B (Isolated Private Workload)](#phase-3-build-vpc-b)
5. [Phase 4: Security Groups Configuration](#phase-4-security-groups-configuration)
6. [Phase 5: Launch the Three EC2 Instances](#phase-5-launch-the-three-ec2-instances)
7. [Phase 6: SSH ProxyJump Setup & Baseline Failure Test](#phase-6-ssh-proxyjump-setup--baseline-failure-test)
8. [Phase 7: Establish VPC Peering Connection](#phase-7-establish-vpc-peering-connection)
9. [Phase 8: Configure Peering Routes](#phase-8-configure-peering-routes)
10. [Phase 9: Verification & Acceptance Tests](#phase-9-verification--acceptance-tests)
11. [Phase 10: Controlled Failure & Recovery Test](#phase-10-controlled-failure--recovery-test)
12. [Phase 11: Clean Up Resources Safely](#phase-11-clean-up-resources-safely)

---

## 1. Overview & Architecture Summary

| Resource Name | Type / Location | IPv4 CIDR / IP | Description |
| :--- | :--- | :--- | :--- |
| `ewb-vpc-a` | VPC | `10.10.0.0/16` | Requester VPC |
| `ewb-a-public` | Subnet (VPC A) | `10.10.1.0/24` | Houses Bastion; has IGW route |
| `ewb-a-private` | Subnet (VPC A) | `10.10.2.0/24` | Houses App-A; private only |
| `ewb-vpc-b` | VPC | `10.20.0.0/16` | Accepter VPC |
| `ewb-b-private` | Subnet (VPC B) | `10.20.1.0/24` | Houses App-B; isolated |
| `ewb-igw-a` | Internet Gateway | Attached to VPC A | Internet egress for Bastion |
| `ewb-bastion` | EC2 (t3.micro) | `10.10.1.10` (+ Public IP) | Administration jump host |
| `ewb-app-a` | EC2 (t3.micro) | `10.10.2.10` (No Public IP) | Private Application A |
| `ewb-app-b` | EC2 (t3.micro) | `10.20.1.10` (No Public IP) | Private Application B |
| `ewb-a-b-peer` | Peering Connection | VPC A <-> VPC B | Private inter-VPC tunnel |

---

## Phase 1: Pre-requisites & Key Pair Creation

1. Open the [AWS Management Console](https://console.aws.amazon.com/).
2. In the top-right region selector, choose **ap-south-1 (Asia Pacific - Mumbai)** (or your designated lab region).
3. Navigate to **EC2** > **Key Pairs** (left sidebar under *Network & Security*).
4. Click **Create key pair**:
   - **Name**: `ewb-lab`
   - **Key pair type**: `RSA`
   - **Private key file format**: `.pem` (for OpenSSH / Linux / WSL / Windows PowerShell)
   - Click **Create key pair**.
5. Save `ewb-lab.pem` to your computer (e.g., `C:\Users\<YourUser>\.ssh\` or your working directory).
   > **Note:** Never upload or paste your private key onto an EC2 instance!

---

## Phase 2: Build VPC A

### Step 1: Create VPC A
1. Go to **VPC Console** > **Your VPCs**.
2. Click **Create VPC**.
3. Select **VPC only** (do NOT choose *VPC and more*, as you need manual control over subnets and route tables).
4. Settings:
   - **Name tag**: `ewb-vpc-a`
   - **IPv4 CIDR block**: `IPv4 CIDR manual input` -> `10.10.0.0/16`
   - **IPv6 CIDR block**: `No IPv6 CIDR block`
   - **Tenancy**: `Default`
   - **Tags**: `Project` = `EWB-VPC-Peering`, `Student` = `<Your Name>`
5. Click **Create VPC**.

### Step 2: Create Subnets in VPC A
1. Go to **VPC** > **Subnets** > **Create subnet**.
2. Select **VPC ID**: choose `ewb-vpc-a`.
3. **Public Subnet**:
   - **Subnet name**: `ewb-a-public`
   - **Availability Zone**: Pick the first AZ (e.g., `ap-south-1a`)
   - **IPv4 CIDR block**: `10.10.1.0/24`
4. Click **Add new subnet** below:
   - **Subnet name**: `ewb-a-private`
   - **Availability Zone**: Pick the **same** AZ (`ap-south-1a`)
   - **IPv4 CIDR block**: `10.10.2.0/24`
5. Click **Create subnet**.

### Step 3: Create & Attach Internet Gateway
1. Go to **VPC** > **Internet gateways** > **Create internet gateway**.
   - **Name tag**: `ewb-igw-a`
   - Click **Create internet gateway**.
2. Click **Actions** > **Attach to VPC**.
   - Select `ewb-vpc-a`.
   - Click **Attach internet gateway**.

### Step 4: Create Route Tables for VPC A
1. **Public Route Table**:
   - Go to **Route tables** > **Create route table**.
   - **Name**: `ewb-rt-a-public`
   - **VPC**: `ewb-vpc-a`
   - Click **Create route table**.
   - Under **Subnet associations** tab, click **Edit subnet associations**.
   - Select `ewb-a-public`. Click **Save associations**.
   - Under **Routes** tab, click **Edit routes** > **Add route**:
     - **Destination**: `0.0.0.0/0`
     - **Target**: `Internet Gateway` -> select `ewb-igw-a`
   - Click **Save changes**.

2. **Private Route Table**:
   - Click **Create route table**.
   - **Name**: `ewb-rt-a-private`
   - **VPC**: `ewb-vpc-a`
   - Click **Create route table**.
   - Under **Subnet associations** tab, click **Edit subnet associations**.
   - Select `ewb-a-private`. Click **Save associations**.
   - *Leave Routes with only the local `10.10.0.0/16` route.* (Do NOT add an internet route!)

> **📸 Checkpoint 01 Screenshot**: Capture the Subnet associations and Routes for `ewb-rt-a-public` (showing `0.0.0.0/0 -> ewb-igw-a`) and `ewb-rt-a-private` (showing only local route).

---

## Phase 3: Build VPC B

1. Go to **VPC** > **Your VPCs** > **Create VPC**.
   - Select **VPC only**.
   - **Name tag**: `ewb-vpc-b`
   - **IPv4 CIDR block**: `10.20.0.0/16`
   - Click **Create VPC**.
2. Go to **Subnets** > **Create subnet**.
   - **VPC ID**: select `ewb-vpc-b`
   - **Subnet name**: `ewb-b-private`
   - **Availability Zone**: Pick the same AZ (`ap-south-1a`)
   - **IPv4 CIDR block**: `10.20.1.0/24`
   - Click **Create subnet**.
3. Go to **Route tables** > **Create route table**.
   - **Name**: `ewb-rt-b-private`
   - **VPC**: `ewb-vpc-b`
   - Click **Create route table**.
   - Under **Subnet associations**, associate `ewb-b-private`.
   - *Keep only the default local `10.20.0.0/16` route for now.*

---

## Phase 4: Security Groups Configuration

Go to **EC2** > **Security Groups** > **Create security group**.

### 1. Bastion SG (`ewb-sg-bastion` in VPC A)
- **Security group name**: `ewb-sg-bastion`
- **Description**: Bastion host SSH access
- **VPC**: `ewb-vpc-a`
- **Inbound rules**:
  - **Type**: `SSH` (Port 22)
  - **Source**: `My IP` (or `<Your-Public-IP>/32`)
- **Outbound rules**: Leave default (All traffic `0.0.0.0/0`)
- Click **Create security group**.

### 2. App-A SG (`ewb-sg-app-a` in VPC A)
- **Security group name**: `ewb-sg-app-a`
- **Description**: App-A Security Group
- **VPC**: `ewb-vpc-a`
- **Inbound rules**:
  - **Rule 1**:
    - **Type**: `SSH` (Port 22)
    - **Source**: `Custom` -> `10.10.1.10/32` (Bastion private IP)
    - **Description**: SSH from Bastion
  - **Rule 2**:
    - **Type**: `Custom ICMP - IPv4`
    - **Protocol**: `ICMP`
    - **Port range**: Select `Echo Request` (Type 8, Code 0)
    - **Source**: `Custom` -> `10.20.1.10/32` (App-B private IP)
    - **Description**: ICMP Echo request from App-B
- Click **Create security group**.

### 3. App-B SG (`ewb-sg-app-b` in VPC B)
- **Security group name**: `ewb-sg-app-b`
- **Description**: App-B Security Group
- **VPC**: `ewb-vpc-b`
- **Inbound rules**:
  - **Rule 1**:
    - **Type**: `SSH` (Port 22)
    - **Source**: `Custom` -> `10.10.1.10/32` (Bastion private IP)
    - **Description**: SSH from Bastion
  - **Rule 2**:
    - **Type**: `Custom ICMP - IPv4`
    - **Port range**: Select `Echo Request` (Type 8, Code 0)
    - **Source**: `Custom` -> `10.10.2.10/32` (App-A private IP)
    - **Description**: ICMP Echo request from App-A
- Click **Create security group**.

---

## Phase 5: Launch the Three EC2 Instances

Navigate to **EC2** > **Instances** > **Launch instances**.

### Instance 1: `ewb-bastion`
1. **Name**: `ewb-bastion`
2. **AMI**: `Amazon Linux 2023 AMI`
3. **Instance type**: `t3.micro` (or `t2.micro`)
4. **Key pair**: `ewb-lab`
5. **Network settings** (Click **Edit**):
   - **VPC**: `ewb-vpc-a`
   - **Subnet**: `ewb-a-public`
   - **Auto-assign public IP**: `Enable`
   - **Firewall (security groups)**: `Select existing security group` -> `ewb-sg-bastion`
   - **Advanced network interface settings** (expand accordion):
     - **Primary IP**: `10.10.1.10`
6. Click **Launch instance**.

### Instance 2: `ewb-app-a`
1. **Name**: `ewb-app-a`
2. **AMI**: `Amazon Linux 2023 AMI`
3. **Instance type**: `t3.micro` (or `t2.micro`)
4. **Key pair**: `ewb-lab`
5. **Network settings** (Click **Edit**):
   - **VPC**: `ewb-vpc-a`
   - **Subnet**: `ewb-a-private`
   - **Auto-assign public IP**: `Disable`
   - **Firewall**: `Select existing security group` -> `ewb-sg-app-a`
   - **Advanced network interface settings**:
     - **Primary IP**: `10.10.2.10`
6. Click **Launch instance**.

### Instance 3: `ewb-app-b`
1. **Name**: `ewb-app-b`
2. **AMI**: `Amazon Linux 2023 AMI`
3. **Instance type**: `t3.micro` (or `t2.micro`)
4. **Key pair**: `ewb-lab`
5. **Network settings** (Click **Edit**):
   - **VPC**: `ewb-vpc-b`
   - **Subnet**: `ewb-b-private`
   - **Auto-assign public IP**: `Disable`
   - **Firewall**: `Select existing security group` -> `ewb-sg-app-b`
   - **Advanced network interface settings**:
     - **Primary IP**: `10.20.1.10`
6. Click **Launch instance**.

> **📸 Checkpoint 02 Screenshot**: Go to EC2 Instances view. Capture the table showing all 3 instances running, their private IPs (`10.10.1.10`, `10.10.2.10`, `10.20.1.10`), and confirming that `ewb-app-a` and `ewb-app-b` have no Public IPv4 address.

---

## Phase 6: SSH ProxyJump Setup & Baseline Failure Test

### 1. Configure SSH on your computer
Get the Public IPv4 of `ewb-bastion` from the EC2 console (e.g. `3.108.x.x`).

On your local machine, open `~/.ssh/config` (or `C:\Users\<YourUser>\.ssh\config` on Windows) and add:
```ssh-config
Host ewb-bastion
    HostName <BASTION_PUBLIC_IP>
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes

Host ewb-app-a
    HostName 10.10.2.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion

Host ewb-app-b
    HostName 10.20.1.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion
```

> In Windows PowerShell, ensure file permissions are restricted:
> ```powershell
> icacls "$HOME\.ssh\ewb-lab.pem" /inheritance:r /grant:r "$($env:USERNAME):(R)"
> ```

### 2. Verify Bastion & App-A Connection
```bash
# Test connection to Bastion
ssh ewb-bastion
exit

# Test ProxyJump connection to App-A
ssh ewb-app-a
```

### 3. Run the Baseline Failure Test (Inside App-A)
Inside `ewb-app-a`, verify your identity and attempt to ping App-B:
```bash
hostname
hostname -I
ping -c 4 10.20.1.10
```
**Expected Result**:
`100% packet loss` (no replies), because VPC Peering and routes have not yet been established.

> **📸 Baseline Screenshot**: Capture the terminal showing `ping -c 4 10.20.1.10` with 100% packet loss.
Type `exit` to return to your laptop.

---

## Phase 7: Establish VPC Peering Connection

1. Go to **VPC Console** > **Peering connections**.
2. Click **Create peering connection**:
   - **Name**: `ewb-a-b-peer`
   - **VPC ID (Requester)**: select `ewb-vpc-a`
   - **Account**: `My account`
   - **Region**: `This Region`
   - **VPC ID (Accepter)**: select `ewb-vpc-b`
3. Click **Create peering connection**.
4. The status will initially be **Pending acceptance**.
5. Select `ewb-a-b-peer`, click **Actions** > **Accept request**.
6. In the modal, click **Accept request**.
7. Status changes to **Active**. Note down the Peering ID (`pcx-xxxxxxxxxxxxxxxxx`).

> **📸 Checkpoint 03 Screenshot**: Capture the Peering Connection console showing `ewb-a-b-peer`, Status = `Active`, Requester = `ewb-vpc-a`, and Accepter = `ewb-vpc-b`.

---

## Phase 8: Configure Peering Routes

Even with an Active peering connection, packets will not route without route table entries!

### 1. Update `ewb-rt-a-private`
- Go to **Route tables** > select `ewb-rt-a-private`.
- Tab **Routes** > **Edit routes** > **Add route**:
  - **Destination**: `10.20.0.0/16`
  - **Target**: `Peering Connection` -> select `ewb-a-b-peer` (pcx-...)
- Click **Save changes**.

### 2. Update `ewb-rt-b-private` (Return Route!)
- Select `ewb-rt-b-private`.
- Tab **Routes** > **Edit routes** > **Add route**:
  - **Destination**: `10.10.0.0/16`
  - **Target**: `Peering Connection` -> select `ewb-a-b-peer` (pcx-...)
- Click **Save changes**.

### 3. Update `ewb-rt-a-public` (For Bastion to App-B SSH)
- Select `ewb-rt-a-public`.
- Tab **Routes** > **Edit routes** > **Add route**:
  - **Destination**: `10.20.0.0/16`
  - **Target**: `Peering Connection` -> select `ewb-a-b-peer` (pcx-...)
- Click **Save changes**.

> **📸 Checkpoint 04 Screenshot**: Capture the Routes tab for all 3 route tables showing the peering target route.

---

## Phase 9: Verification & Acceptance Tests

### Test 1: SSH into App-B via ProxyJump (From your laptop)
```bash
ssh ewb-app-b
```
**Expected Result**: You successfully get a shell on `ewb-app-b` (`10.20.1.10`) hopping through `ewb-bastion`!

### Test 2: Reverse Path Ping (From inside App-B to App-A)
```bash
hostname -I
ping -c 4 10.10.2.10
```
**Expected Result**: `4 packets transmitted, 4 received, 0% packet loss`.
Type `exit` to return to your laptop.

### Test 3: Forward Path Ping (From inside App-A to App-B)
```bash
ssh ewb-app-a
hostname -I
ping -c 4 10.20.1.10
```
**Expected Result**: `4 packets transmitted, 4 received, 0% packet loss`.

> **📸 Acceptance Screenshots**:
> 1. Terminal showing successful forward ping (App-A -> App-B) with `0% packet loss`.
> 2. Terminal showing successful reverse ping (App-B -> App-A) with `0% packet loss`.
> 3. Terminal showing successful SSH login into `ewb-app-b`.

---

## Phase 10: Controlled Failure & Recovery Test

To prove that the Security Group is actually enforcing isolation:

1. **Simulate Failure**:
   - Go to **EC2** > **Security Groups** > select `ewb-sg-app-b`.
   - Click **Edit inbound rules**.
   - **Delete** the ICMP Echo Request rule (the rule with port range Echo Request and source `10.10.2.10/32`).
   - Click **Save rules**.
   *(Keep the SSH rule intact!)*

2. **Run Test during failure (Inside App-A)**:
   ```bash
   ping -c 4 10.20.1.10
   ```
   **Observed Result**: Packets time out, `100% packet loss`!

3. **Restore & Recover**:
   - Go back to `ewb-sg-app-b` > **Edit inbound rules** > **Add rule**:
     - **Type**: `Custom ICMP - IPv4` -> `Echo Request`
     - **Source**: `10.10.2.10/32`
   - Click **Save rules**.

4. **Verify Recovery (Inside App-A)**:
   ```bash
   ping -c 4 10.20.1.10
   ```
   **Observed Result**: Ping immediately recovers! `0% packet loss`.

> **📸 Controlled Failure Screenshots**:
> 1. Ping failure showing 100% loss during SG rule removal.
> 2. Restored ping showing 0% loss after restoring rule.

---

## Phase 11: Clean Up Resources Safely

Always tear down resources to prevent unwanted AWS charges:

1. **Terminate EC2 Instances**:
   - EC2 > Instances > Select `ewb-bastion`, `ewb-app-a`, `ewb-app-b`.
   - Instance state > **Terminate instance**.
   - Wait until all show *Terminated*.
2. **Delete VPC Peering Connection**:
   - VPC > Peering connections > Select `ewb-a-b-peer` > Actions > **Delete peering connection**.
3. **Delete Route Tables & Subnets**:
   - Delete custom routes from route tables.
   - Subnets > Delete `ewb-a-public`, `ewb-a-private`, `ewb-b-private`.
   - Route tables > Delete `ewb-rt-a-public`, `ewb-rt-a-private`, `ewb-rt-b-private`.
4. **Detach & Delete Internet Gateway**:
   - Internet gateways > Select `ewb-igw-a` > Actions > **Detach from VPC**.
   - Actions > **Delete internet gateway**.
5. **Delete Security Groups**:
   - Delete `ewb-sg-bastion`, `ewb-sg-app-a`, `ewb-sg-app-b`.
6. **Delete VPCs**:
   - Select and delete `ewb-vpc-a` and `ewb-vpc-b`.
7. **Clean up Key Pair**:
   - EC2 > Key Pairs > Delete `ewb-lab`.

> **📸 Cleanup Screenshot**: Capture the EC2 / VPC console showing instances terminated and VPCs removed.
