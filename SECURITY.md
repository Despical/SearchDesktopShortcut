# Security Policy

Please report vulnerabilities in SearchDesktopShortcut privately rather than opening a public issue.

## Reporting a vulnerability

Send reports to **contact@despical.dev**. Include the project version, Windows version and build, reproduction steps and the expected impact. Attach a minimal proof of concept where useful, and remove personal paths and account details.

## Scope

This policy covers the installer scripts, the menu patch and the `desktopshortcut:` protocol handler. Security-sensitive areas include:

- Validation of protocol requests, shortcut names and shortcut targets.
- Paths written by the helper, installer and uninstaller.
- Temporary permission changes made while patching or restoring the local Windows Search copy.
- Backup integrity and restoration.

Vulnerabilities in Windows or Windows Search itself should be reported to Microsoft.

## Supported versions

Only the latest release receives security fixes.

## Response and disclosure

Reports will be reviewed and reproduced where possible. Confirmed issues will be fixed before disclosure, with reporter credit when agreed. Please coordinate disclosure until a fix is available. No fixed response deadline is promised.
