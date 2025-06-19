# GPO via Microsoft Live reponse in MDE

Purpose is to allow for the Local GPO to be updated via Live Response
This is a manual affair for each computer but does not require physical assess

Assumptions:

1.  Computer is on and available in Live Response
2.  Files can be downloaded from this Github
3.  Files will automatically overwrite but registry.pol needs to be updated on changes
4.  The Sysinternals directory should be in existance on the endpoint but created it if it is not
5.  Another script is responsible for updating the SysInternals system to enhance MDE

Shortcomings

1.  A single registry.pol file is used which applies to the computer not the user
2.  Changed the group policy on the prototype device to ignore user configuration - need to see how this works
3.  Might need to change this back but at the moment the code in this repository is not affected.
4.  File is in the public domain but okay with this for the time being
5.  secedit SECURITYPOLICY needs fixing ASAP - making headway on this.


Fixed

1.  Fixed all the coding errors - my bad
2.  Tested on a purged system via local execution and Live response
3.  All policies have been updated and reflected in Microsoft Security Portal although it takes time to reflect - 6+ hours


Disclaimer

1.  I am not responsible if you implement my script on your machine
2.  I am not responsible if you get hacked after implementing my script on your machine
3.  Basically, I am not responsible
4.  To the best of my knowledge there is no downside to using this GPO and there is definitely no malicious intent.


Outstanding

1.  Registy is not the problem its secedit
2.  Create a roll back function - basic coding done - testing not so much
3.  Create a ASR audit function - created - testing not so much
4.  Do not publish code till you test it.


Links

1. https://www.braedach.com/microsoft-group-policy/
2. https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/windows-security-baselines
3. https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference#asr-rule-to-guid-matrix


