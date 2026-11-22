// SearchDesktopShortcut - Copyright (C) 2026 Berke Akcen
// Licensed under the GNU General Public License v3.0 or later. See LICENSE.
//
// Template for the patched menu call. Comment lines are removed and the remaining
// lines are trimmed and joined, so every statement must end with its own separator.
// @NS@, @VERBS@, @X@ and @Y@ are the minified names found at the patch location.
// @LABEL@ is the menu text for the Windows display language.
this.innerShowContextMenu(/*DesktopShortcutPatch*/((dsV, dsS) => {
try {
let dsD = @NS@.getItemWithFileMetadata(dsS),
dsP = dsD && (dsD.filePath || dsD.id),
dsR = /^(start|taskbar)(un)?pin$/i;
if (dsP && @NS@.isApp(dsS.type) && dsV.some(dsX => dsX.verb && dsR.test(dsX.verb))) {
let dsH = dsZ => Array.from({length: dsZ.length}, (dsU, dsK) => ("000" + dsZ.charCodeAt(dsK).toString(16)).slice(-4)).join(""),
dsA = dsV.findIndex(dsX => dsX.verb && dsX.verb.toLowerCase() == "openfilelocation"),
dsB = dsA >= 0 ? dsA + 1 : dsV.findIndex(dsX => dsX.verb && dsR.test(dsX.verb));
dsV = dsV.slice();
dsV.splice(dsB, 0, {
verb: "CreateDesktopShortcut",
displayName: "@LABEL@",
icon: {type: 1, content: "&#xE7F4"},
executeSync: () => {
@NS@.Host.launchUriAsync("desktopshortcut:" + dsH(String(dsD.displayName || dsS.text || "Shortcut")) + "-" + dsH(String(dsP)), !0);
}
});
}
} catch (dsX) {}
return dsV;
})(@NS@.extendVerbs(@VERBS@, t, this._page), t), @X@, @Y@,
