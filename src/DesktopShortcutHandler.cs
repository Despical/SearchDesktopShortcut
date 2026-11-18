// SearchDesktopShortcut - Copyright (C) 2026 Berke Akcen
// Licensed under the GNU General Public License v3.0 or later. See LICENSE.

using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;
using System.Text.RegularExpressions;

[ComImport, Guid("00021401-0000-0000-C000-000000000046")]
internal class ShellLink { }

// Members must stay in vtable order. Unused slots only reserve their position.
[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
internal interface IShellLinkW {
    void GetPath();
    void GetIDList();
    void SetIDList(IntPtr pidl);
    void GetDescription();
    void SetDescription();
    void GetWorkingDirectory();
    void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string path);
    void GetArguments();
    void SetArguments();
    void GetHotkey();
    void SetHotkey();
    void GetShowCmd();
    void SetShowCmd();
    void GetIconLocation();
    void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string path, int index);
    void SetRelativePath();
    void Resolve();
    void SetPath([MarshalAs(UnmanagedType.LPWStr)] string path);
}

internal static class Program {
    private const int Success = 0;
    private const int InvalidRequest = 1;
    private const int UnsupportedTarget = 2;
    private const int Failure = 3;

    private static readonly Regex Request = new Regex(
        "^desktopshortcut:((?:[0-9a-f]{4})+)-((?:[0-9a-f]{4})+)/?$",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    private static readonly Regex AppId = new Regex(
        @"^[A-Za-z0-9_.-]+(![A-Za-z0-9_.-]+)?$|^\{[0-9A-Fa-f-]{36}\}\\[A-Za-z0-9_. \\-]+$",
        RegexOptions.CultureInvariant);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SHParseDisplayName(string name, IntPtr context, out IntPtr pidl, uint attributes, out uint result);

    [STAThread]
    private static int Main(string[] args) {
        if (args.Length != 1) return InvalidRequest;
        Match request = Request.Match(args[0]);
        if (!request.Success) return InvalidRequest;

        try {
            return CreateShortcut(Decode(request.Groups[1].Value), Decode(request.Groups[2].Value));
        }
        catch (Exception) {
            return Failure;
        }
    }

    private static string Decode(string hex) {
        StringBuilder text = new StringBuilder(hex.Length / 4);
        for (int i = 0; i < hex.Length; i += 4) {
            text.Append((char) Convert.ToInt32(hex.Substring(i, 4), 16));
        }
        return text.ToString();
    }

    private static int CreateShortcut(string name, string target) {
        string destination = GetDestination(name);

        if (Regex.IsMatch(target, @"^[A-Za-z]:\\")) {
            string path = Path.GetFullPath(target);
            if (!File.Exists(path)) return UnsupportedTarget;

            string extension = Path.GetExtension(path).ToLowerInvariant();
            if (extension == ".lnk" && IsInStartMenu(path)) {
                File.Copy(path, destination, false);
                return Success;
            }
            if (extension == ".exe") {
                IShellLinkW link = (IShellLinkW) new ShellLink();
                link.SetPath(path);
                link.SetWorkingDirectory(Path.GetDirectoryName(path));
                link.SetIconLocation(path, 0);
                ((IPersistFile) link).Save(destination, true);
                return Success;
            }
            return UnsupportedTarget;
        }

        if (target.Contains("..") || !AppId.IsMatch(target)) return UnsupportedTarget;
        return CreateAppShortcut(target, destination);
    }

    private static int CreateAppShortcut(string appId, string destination) {
        IntPtr pidl;
        uint ignored;
        if (SHParseDisplayName("shell:AppsFolder\\" + appId, IntPtr.Zero, out pidl, 0, out ignored) != 0) {
            return UnsupportedTarget;
        }

        try {
            IShellLinkW link = (IShellLinkW) new ShellLink();
            link.SetIDList(pidl);
            ((IPersistFile) link).Save(destination, true);
            return Success;
        }
        finally {
            Marshal.FreeCoTaskMem(pidl);
        }
    }

    private static bool IsInStartMenu(string path) {
        return IsUnder(path, Environment.GetFolderPath(Environment.SpecialFolder.StartMenu))
            || IsUnder(path, Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu));
    }

    private static bool IsUnder(string path, string folder) {
        return folder.Length > 0
            && path.StartsWith(folder.TrimEnd('\\') + "\\", StringComparison.OrdinalIgnoreCase);
    }

    private static string GetDestination(string name) {
        string desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        string clean = Regex.Replace(name, "[\\\\/:*?\"<>|\\x00-\\x1f]", " ").Trim().TrimEnd('.');
        if (clean.Length > 80) clean = clean.Substring(0, 80).Trim();
        if (clean.Length == 0 || clean[0] == '.') clean = "Shortcut";

        string candidate = Path.Combine(desktop, clean + ".lnk");
        for (int number = 2; File.Exists(candidate); number++) {
            candidate = Path.Combine(desktop, clean + " (" + number + ").lnk");
        }
        return candidate;
    }
}
