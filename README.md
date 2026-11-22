<p align="center">
  <img src="assets/icon.svg" width="128" height="128" alt="SearchDesktopShortcut icon">
</p>

<h1 align="center">SearchDesktopShortcut</h1>

<p align="center">Adds a <strong>Create desktop shortcut</strong> action to the Windows 10 Search context menu.</p>

<p align="center">
  <img src="https://img.shields.io/badge/Windows_10-22H2-0078D4" alt="Windows 10 22H2">
  <img src="https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&amp;logoColor=white" alt="PowerShell 5.1">
  <img src="https://img.shields.io/badge/.NET_Framework-4.x-512BD4" alt=".NET Framework 4.x">
  <a href="https://github.com/Despical/SearchDesktopShortcut/actions/workflows/ci.yml"><img src="https://github.com/Despical/SearchDesktopShortcut/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPLv3-blue" alt="GPLv3 license"></a>
</p>

<p align="center"><a href="https://github.com/Despical/SearchDesktopShortcut/releases/latest">Download</a> · <a href="#installation">Installation</a> · <a href="#updating">Updating</a> · <a href="#uninstalling">Uninstalling</a> · <a href="#how-it-works">How It Works</a> · <a href="#security">Security</a></p>

---

## Features

- Adds **Create desktop shortcut** below **Open file location** in the Windows Search right-click menu.
- Works with desktop programs and Microsoft Store apps.
- Creates real app shortcuts, so they keep the app's own icon.
- Keeps Bing and web results in Windows Search enabled.
- Reapplies itself when Bing sends a new version of the Search interface, for example after a restart.
- Installs for the current user without administrator rights.
- Backs up every file it changes and restores them on uninstall.

## Requirements

- Windows 10 version 22H2. It was developed and tested on build 19045.
- Windows PowerShell 5.1 and .NET Framework 4.x, both included with Windows 10.
- Open Windows Search at least once before installing, so its menu code is cached.

Windows 11 is not supported or tested. Its Search interface is different.

## Installation

1. Download `SearchDesktopShortcut-<version>.zip` from the [latest release](https://github.com/Despical/SearchDesktopShortcut/releases/latest).
2. Extract the archive to a folder you will keep.
3. Run `Install.cmd`.
4. Open Windows Search, right-click an app and choose **Create desktop shortcut**.

Windows may show a SmartScreen prompt for downloaded scripts. Review the files first if you want to confirm what they do.

## Updating

Microsoft delivers the Search interface through Bing and replaces it often, including after a restart. A small background helper starts when you sign in, notices new Search files and patches them within a few seconds. The next time you open Search, the menu item is back.

To update SearchDesktopShortcut itself, extract the new release and run its `Install.cmd`. Running it repeatedly is safe.

If Microsoft changes the menu code itself, the helper leaves the new files unchanged and writes the reason to `%LOCALAPPDATA%\SearchDesktopShortcut\watcher.log`. In that case, please [open an issue](https://github.com/Despical/SearchDesktopShortcut/issues).

## Using Search without web results

`Install.cmd` patches the interface used when web search is enabled. If you turned web search off, Windows Search loads its local copy from a protected system folder. Run `InstallLocalCopy.cmd` and approve the administrator prompt to patch that copy as well.

The script briefly takes write access to one file, then returns its original owner and permissions. A Windows update may replace this file.

## Uninstalling

Run `Uninstall.cmd`. It stops the background helper, removes its sign-in entry, restores the original files, removes the protocol handler and deletes the data folder. If the local copy was patched, Windows asks for administrator approval. Shortcuts already on your desktop are kept.

## How it works

| Part | Location | Purpose |
| --- | --- | --- |
| Menu patch | Windows Search web cache in your user profile | Adds the menu item. The file size stays the same, because Windows Search discards cached files whose size changes. |
| Protocol handler | `HKCU\Software\Classes\desktopshortcut` | Lets Windows Search hand the selected app to the helper. |
| Helper | `%LOCALAPPDATA%\SearchDesktopShortcut` | Compiled from [`src/DesktopShortcutHandler.cs`](src/DesktopShortcutHandler.cs) during installation. It creates the shortcut and watches the Search cache. |
| Sign-in entry | `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` | Starts the helper in watch mode when you sign in. |
| Installed scripts | `%LOCALAPPDATA%\SearchDesktopShortcut\app` | A copy of the scripts the helper uses to patch new Search files. |
| Backups | `%LOCALAPPDATA%\SearchDesktopShortcut` | Original copies used by the uninstaller. |

To make room for the patch, the installer empties some internal diagnostic error texts in the cached file. This does not change normal Search behavior, but those errors will have empty messages in logs.

## Security

The `desktopshortcut:` protocol can be opened by any program, and by a website if you approve the browser prompt. The helper can only create a shortcut on your desktop. It never starts the target, accepts no command-line arguments for it and rejects network paths. It accepts local `.exe` files, `.lnk` files from the Start menu and valid app IDs.

Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## Development

Run the tests from the repository root. They need Node.js and do not touch Windows Search files.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Run-Tests.ps1
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md).

## Disclaimer

This project changes files used by Windows Search and is provided without warranty. It is not affiliated with or endorsed by Microsoft. Windows and Bing are trademarks of Microsoft Corporation.

## License

Copyright © 2026 Berke Akçen. SearchDesktopShortcut is licensed under the [GNU General Public License v3.0 or later](LICENSE).
