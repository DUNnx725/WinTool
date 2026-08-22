# Security Policy

Security and reliability are important goals of WinTool.

WinTool interacts with Windows system settings and diagnostic tools, so security-related problems should be reported responsibly.

## Supported Versions

WinTool v1.1.x is the current supported public release.

| Version | Supported |
| ------- | --------- |
| 1.1.x   | Yes       |
| 1.0.x   | No        |
| < 1.0   | No        |

Development builds and internal test versions are not considered supported public releases.

## Reporting a Security Vulnerability

Please do not publicly disclose a security vulnerability through a GitHub Issue if it could put users at risk.

When available, use GitHub's **Private Vulnerability Reporting** feature for this repository.

Examples of security issues that should be reported privately include:

- unintended execution of commands;
- privilege or elevation problems;
- unsafe modification of Windows settings;
- command or argument injection;
- unsafe file or path handling;
- unexpected deletion or modification of user data;
- vulnerabilities involving downloaded or external components;
- behavior that could compromise the security of the user's system.

For normal bugs, interface problems, translation errors, feature requests or non-security-related problems, please use GitHub Issues.

## What to Include

A useful security report should include, when possible:

- affected WinTool version;
- Windows version;
- affected feature or component;
- steps required to reproduce the problem;
- expected behavior;
- actual behavior;
- relevant logs or error messages.

Please remove passwords, tokens, personal information and other sensitive data before attaching logs, screenshots or reports.

## Response

Security reports will be reviewed before a fix or public disclosure is made.

If a vulnerability is confirmed, the goal is to correct the affected functionality and provide an updated release when appropriate.

Please allow reasonable time for investigation and correction before publicly disclosing a reported vulnerability.

## Scope

This security policy applies to WinTool source code and functionality maintained by the WinTool project.

Third-party software used or accessed by WinTool is maintained by its respective developers. Vulnerabilities originating entirely from a third-party project should generally also be reported to that project's maintainers.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for information about third-party components.

## General Safety

Download WinTool only from the official GitHub repository and its official Releases.

Before running modified or redistributed versions, users should review their source and origin.

WinTool does not require users to disable Windows Defender, Windows Update or other critical Windows security services in order to use the official release.

---

WinTool is an open-source project developed by **DUNnx725**.
