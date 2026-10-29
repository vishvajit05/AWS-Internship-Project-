# SSH Client & ProxyJump Setup Guide (Windows / Mac / Linux)

This guide shows you how to securely configure OpenSSH on Windows PowerShell (as well as macOS / Linux / WSL) to connect seamlessly to your private EC2 instances via Bastion ProxyJump without copying private keys to any cloud server.

---

## 1. Store Your Private Key Securely

When you download `ewb-lab.pem` from the AWS EC2 Console, place it inside your user's `.ssh` directory:
- **Windows Path**: `C:\Users\<YourUsername>\.ssh\ewb-lab.pem`
- **Linux/Mac Path**: `~/.ssh/ewb-lab.pem`

---

## 2. Fix Key File Permissions (Crucial!)

SSH clients will reject your key if other users have read permissions ("UNPROTECTED PRIVATE KEY FILE!").

### On Windows (Run in PowerShell as your normal user):
```powershell
# Navigate to your .ssh folder
cd $HOME\.ssh

# Reset inheritance and grant read-only permission strictly to your Windows user account
icacls.exe "ewb-lab.pem" /reset
icacls.exe "ewb-lab.pem" /inheritance:r
icacls.exe "ewb-lab.pem" /grant:r "$($env:USERNAME):(R)"
```

### On macOS / Linux / WSL:
```bash
chmod 400 ~/.ssh/ewb-lab.pem
```

---

## 3. Configure `~/.ssh/config`

Create or open the file `config` in your `.ssh` directory:
- Windows: `C:\Users\<YourUsername>\.ssh\config`
- Linux/Mac: `~/.ssh/config`

Add the following block (replace `REPLACE_WITH_BASTION_PUBLIC_IP` with the actual public IPv4 address of `ewb-bastion`):

```ssh-config
Host ewb-bastion
    HostName REPLACE_WITH_BASTION_PUBLIC_IP
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

---

## 4. Testing Your Connections

### Step 1: Connect to the Bastion Host
```powershell
ssh ewb-bastion
```
*(Accept the fingerprint prompt by typing `yes` when connecting for the first time)*  
Once logged in, type `exit` to return to your local machine.

### Step 2: Connect to App-A via Bastion ProxyJump
```powershell
ssh ewb-app-a
```
Your laptop opens an encrypted SSH tunnel through Bastion directly to App-A (`10.10.2.10`).

### Step 3: Run Baseline Ping from App-A (Before Peering)
```bash
# Verify hostname and IP
hostname
hostname -I

# Ping App-B (should fail with 100% loss before peering routes)
ping -c 4 10.20.1.10
```

### Step 4: Connect to App-B (After Peering & Routes Configured)
```powershell
ssh ewb-app-b
```
You can now directly manage App-B over the peered VPC private connection!
