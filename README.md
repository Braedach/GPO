---

## 🛠️ GPO via Microsoft Live Response in MDE

### 🎯 Purpose
Enable updates to the Local Group Policy Object (GPO) via Microsoft Defender for Endpoint (MDE) Live Response. This process is manual per device but does **not** require physical access.

---

### ✅ Assumptions
- Target computer is online and accessible via Live Response.
- Required files are downloadable from the linked GitHub repository.
- Files will overwrite existing ones automatically; however, `registry.pol` must be updated when changes occur.
- The GPO directory is now **separated** from Sysinternals.
- A separate script manages Sysinternals updates to enhance MDE functionality.

---

### ⚠️ Shortcomings
- A single `registry.pol` file is used, applying **machine-level** policies only (not user-specific).
- Prototype device has been configured to **ignore user configuration**—this needs further validation.
- Reverting this change may be necessary, but current repository code remains unaffected.
- The file is publicly accessible; acceptable for now.

---

### 🧹 Fixes Implemented
- Resolved all coding errors (my oversight).
- Addressed `secedit` database reset issue; added workaround code.
- Successfully tested on a **purged system** via both local execution and Live Response.
- Policies are now reflected in the **Microsoft Security Portal**, though propagation may take **6+ hours**.

---

### 📌 Disclaimer
- I am **not responsible** if you implement this script on your machine.
- I am **not responsible** if your system is compromised after using this script.
- In short: **use at your own risk**.

---

### 🔄 Outstanding Items
- GPO configurations are **continually evolving**—expect ongoing updates to the policy file.

---

### 🔗 Reference Links
- [Braedach: Microsoft Group Policy Overview](https://www.braedach.com/microsoft-group-policy/)
- [Windows Security Baselines](https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/windows-security-baselines)
- [ASR Rule to GUID Matrix](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference#asr-rule-to-guid-matrix)

---

This respository is controlled by a bio with the help of an AI.  Cheers