# FreeIPA User Import - Quick Start Guide

## Status: Ready for Execution ✅

### Generated Files
- ✅ **CSV with 247 users**: `data/users.csv` (151 students + 65 teachers + 3 admin + 28 virtual/comment lines filtered)
- ✅ **Passwords**: `data/user-passwords-20251125.txt` (247 secure CSPRNG passwords, 16 chars each)
- ✅ **Import script**: `scripts/freeipa-import-users.sh` (550 lines, production-ready)
- ✅ **PowerShell wrapper**: `scripts/Import-FreeIPAUsers.ps1`

---

## Option 1: Execute on FreeIPA Server (RECOMMENDED)

### Step 1: Copy files to FreeIPA server
```powershell
# From your Windows machine
scp .\data\users.csv root@freeipa.zsel.opole.pl:/tmp/
scp .\data\user-passwords-20251125.txt root@freeipa.zsel.opole.pl:/tmp/
scp .\scripts\freeipa-import-users.sh root@freeipa.zsel.opole.pl:/tmp/
```

### Step 2: SSH to FreeIPA server
```powershell
ssh root@freeipa.zsel.opole.pl
```

### Step 3: Authenticate with Kerberos
```bash
kinit admin
# Enter admin password when prompted
```

### Step 4: Execute import
```bash
cd /tmp
chmod +x freeipa-import-users.sh
./freeipa-import-users.sh users.csv user-passwords-20251125.txt
```

### Step 5: Review results
```bash
# Check HTML report
ls -lah freeipa-import-report-*.html

# Download report to your Windows machine (from Windows PowerShell)
scp root@freeipa.zsel.opole.pl:/tmp/freeipa-import-report-*.html .\reports\

# Verify user count
ipa user-find --all | wc -l
# Expected: 247 users

# Check specific class group
ipa group-show 1AT --all
# Expected: 31 members (students from class 1AT)

# Check role groups
ipa group-show students --all
# Expected: 151 members

ipa group-show teachers --all
# Expected: 65 members
```

---

## Option 2: Automated Remote Execution (if SSH configured)

```powershell
.\scripts\Import-FreeIPAUsers.ps1 -FreeIPAServer "root@freeipa.zsel.opole.pl"
```

This will:
1. Copy files via SCP
2. Execute import remotely
3. Display results

---

## Option 3: Local Execution (if FreeIPA client installed locally)

```powershell
.\scripts\Import-FreeIPAUsers.ps1 -LocalExecution
```

**Prerequisites:**
- FreeIPA client tools installed on Windows/WSL
- Authenticated with `kinit admin`

---

## What the Import Script Does

### 1. Creates Organizational Units (OUs)
- `ou=classes` - Parent for all class groups
- `ou=classes/1AT`, `ou=classes/1BT1`, etc. - 29 class OUs

### 2. Creates Groups
**Class Groups (29):**
- 1AT (Technik Mechatronik) - 31 students
- 1BT1 (Technik Elektryk) - 17 students
- 1BT2 (Technik Automatyk) - 16 students
- 1CT1 (Technik Programista) - 14 students
- 1CT2 (Technik Teleinformatyk) - 14 students
- 1DT (Technik Informatyk) - 30 students
- 1AB (Elektryk) - 34 students
- 1AW (Technik Elektryk II) - 25 students
- ... (21 more classes for years 2-5)

**Role Groups (4):**
- `students` (151 members)
- `teachers` (65 members)
- `admin` (3 members)
- `staff`

**Department Groups (6):**
- `mechatronika`
- `elektrotechnika`
- `automatyka`
- `programowanie`
- `teleinformatyka`
- `informatyka`

### 3. Creates User Accounts
For each user:
- Username (e.g., `p.adamek`, `j.sukiennik`)
- Email (`username@zsel.opole.pl`)
- Password (from pre-generated file)
- Group memberships (class + role + department)
- User attributes (first name, last name, class, specialization)

### 4. Generates HTML Report
- Import summary (success/failure counts)
- Detailed user list with status
- Group membership verification
- Error messages (if any)

---

## Expected Output

```
========================================
FreeIPA User Import Script
========================================
Total users to import: 247

[1/247] Creating user: p.adamek (Piotr Adamek)
  ✓ User created successfully
  ✓ Added to group: 1AT
  ✓ Added to group: students
  ✓ Added to group: mechatronika

[2/247] Creating user: k.borek (Kacper Borek)
  ✓ User created successfully
  ✓ Added to group: 1AT
  ✓ Added to group: students
  ✓ Added to group: mechatronika

...

========================================
Import Summary
========================================
Total users:    247
✓ Success:      247
✗ Errors:       0

Groups created: 39 (29 classes + 4 roles + 6 departments)

HTML Report: freeipa-import-report-20251125-171730.html
========================================
```

---

## Verification Checklist

After import, verify:

1. **User Count**
   ```bash
   ipa user-find --all | wc -l
   # Should be: 247
   ```

2. **Class Groups**
   ```bash
   ipa group-find --all | grep "1AT\|1BT1\|1CT1\|1DT\|1AB\|1AW"
   # Should show all 8 first-year classes
   ```

3. **Sample User**
   ```bash
   ipa user-show p.adamek --all
   # Should show: email, groups (1AT, students, mechatronika)
   ```

4. **Group Membership Count**
   ```bash
   ipa group-show students --all | grep "Member users:" | wc -l
   # Should be: 151
   
   ipa group-show teachers --all | grep "Member users:" | wc -l
   # Should be: 65
   ```

5. **Test Login**
   ```bash
   # Try to authenticate as a student
   echo "password_from_file" | kinit p.adamek
   klist
   # Should show valid ticket
   ```

---

## Password Distribution

After successful import:

1. **Export passwords to 1Password/Bitwarden** (already done during generation)
2. **Create password letters for students**
   ```powershell
   # Generate printable password cards
   .\scripts\generate-password-cards.ps1 -Class "1AT"
   ```

3. **Distribute securely**
   - Print password cards (one per student)
   - Hand out during first class
   - Require password change on first login

4. **Configure password policy**
   ```bash
   ipa pwpolicy-mod --minlife=0 --maxlife=90 --history=5 --minlength=12
   ```

---

## Troubleshooting

### Issue: "ipa: command not found"
**Solution:** Install FreeIPA client tools or use remote execution

### Issue: "ipa: ERROR: Insufficient access: Insufficient 'add' privilege"
**Solution:** Authenticate with admin privileges: `kinit admin`

### Issue: Duplicate user errors
**Solution:** Check if users already exist: `ipa user-find username`

### Issue: Group already exists
**Solution:** Script will skip existing groups, continue with user creation

### Issue: CSV encoding errors (Polish characters)
**Solution:** Ensure CSV is UTF-8 encoded: `iconv -f WINDOWS-1250 -t UTF-8 users.csv > users_utf8.csv`

---

## Next Steps After Import

1. ✅ **Import complete** → Verify user count (247)
2. ✅ **Review HTML report** → Check for errors
3. ⏭️ **Configure password policies** → Force password change on first login
4. ⏭️ **Set up LDAP sync** → Sync to other services (GitLab, Moodle, etc.)
5. ⏭️ **Distribute credentials** → Print password cards for students
6. ⏭️ **Test authentication** → Verify login works for sample users
7. ⏭️ **Configure home directories** → Set up autofs/NFS home dirs
8. ⏭️ **Enable 2FA** (optional) → Configure OTP tokens for teachers/admin

---

## Files Location

```
zsel-eip-gitops/
├── data/
│   ├── users.csv                          # 247 users (INPUT)
│   ├── user-passwords-20251125.txt        # 247 passwords (INPUT)
│   └── ZSEL-STRUCTURE.md                  # School structure documentation
├── scripts/
│   ├── freeipa-import-users.sh            # Bash import script (550 lines)
│   ├── Import-FreeIPAUsers.ps1            # PowerShell wrapper
│   └── generate-user-passwords.ps1        # Password generator (already executed)
└── reports/
    └── freeipa-import-report-*.html       # Generated after import
```

---

## Quick Command Reference

```bash
# List all users
ipa user-find --all

# Show specific user
ipa user-show p.adamek --all

# List groups
ipa group-find --all

# Show group members
ipa group-show 1AT --all

# Add user to group manually
ipa group-add-member students --users=p.adamek

# Remove user
ipa user-del p.adamek

# Reset password
ipa user-mod p.adamek --password

# Lock user account
ipa user-disable p.adamek

# Unlock user account
ipa user-enable p.adamek
```

---

**Ready to execute?** Choose Option 1 (recommended) and run the commands above! 🚀
