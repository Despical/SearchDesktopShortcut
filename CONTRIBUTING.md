# Contributing

Thanks for helping improve SearchDesktopShortcut. Discuss substantial changes in an issue before opening a pull request, follow the [Code of Conduct](CODE_OF_CONDUCT.md) and report vulnerabilities privately through [SECURITY.md](SECURITY.md).

By contributing, you agree that your contribution is licensed under the [GNU General Public License v3.0 or later](LICENSE).

## Run the tests

Use Windows 10 with Windows PowerShell 5.1 and Node.js:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Run-Tests.ps1
```

The tests use a synthetic bundle. They create temporary shortcuts on the desktop and remove them afterward.

## Conventions

- Keep PowerShell, batch and C# files ASCII, because Windows PowerShell 5.1 reads files without a byte order mark using the system code page.
- Use four spaces in PowerShell, C# and JavaScript.
- Write code, comments, messages and documentation in English.
- Never commit files copied from Windows Search or other Microsoft code.
- Keep every change to a Windows file backed up and reversible.

## Reports and pull requests

Include the Windows version and build, the output of `scripts\SearchDesktopShortcut.ps1 -Action Status`, reproduction steps and the resulting behavior. Remove personal paths from anything you share.

Keep pull requests focused and state which checks you ran. Passing tests do not prove that the real Search menu works, so also describe what you verified in Windows Search.
