// SearchDesktopShortcut - Copyright (C) 2026 Berke Akcen
// Licensed under the GNU General Public License v3.0 or later. See LICENSE.

"use strict";

const assert = require("assert");
const fs = require("fs");
const vm = require("vm");

const [original, patched] = process.argv.slice(2).map(file => fs.readFileSync(file, "latin1"));
assert.strictEqual(patched.length, original.length, "the patch must keep the bundle size");
assert.ok(patched.includes("/*DesktopShortcutPatch*/"), "the patch marker is missing");

function openMenu(verbs, item, launched) {
    const context = {
        launched,
        verbs,
        item,
        shown: null
    };
    vm.runInNewContext(patched + `
        WSB.host.launch = (uri, dismiss) => launched.push({uri, dismiss});
        shown = new WSB.Menu().open(verbs, item);
    `, context);
    return context.shown;
}

const verbs = ["runas", "openfilelocation", "startpin", "taskbarpin"].map(verb => ({verb}));
const launched = [];
const shown = openMenu(verbs, {type: "app", deviceItem: {displayName: "Ab", filePath: "C:\\A.lnk"}}, launched);

assert.deepStrictEqual(
    Array.from(shown, entry => entry.verb),
    ["runas", "openfilelocation", "CreateDesktopShortcut", "startpin", "taskbarpin"]
);
assert.strictEqual(shown[2].displayName, "Create desktop shortcut");
assert.strictEqual(shown[2].icon.content, "&#xE7F4");

shown[2].executeSync();
assert.strictEqual(launched.length, 1);
assert.strictEqual(launched[0].uri, "desktopshortcut:00410062-0043003a005c0041002e006c006e006b");
assert.strictEqual(launched[0].dismiss, true);

const modern = openMenu([{verb: "startpin"}], {type: "app", deviceItem: {id: "Vendor.App_abc!App"}}, []);
assert.strictEqual(modern[0].verb, "CreateDesktopShortcut");

assert.strictEqual(openMenu(verbs, {type: "file", deviceItem: {filePath: "C:\\A.txt"}}, []).length, verbs.length);
assert.strictEqual(openMenu(verbs, {type: "app"}, []).length, verbs.length);
assert.strictEqual(openMenu([{verb: "open"}], {type: "app", deviceItem: {id: "A"}}, []).length, 1);

console.log("Patch tests passed.");
