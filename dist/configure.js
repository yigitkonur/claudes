"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.configure = configure;
exports.builtInNames = builtInNames;
const config_1 = require("./config");
const utils_1 = require("./utils");
function presetNames(data) {
    return Object.keys(data.presets || {});
}
function upsertPreset(data, name, preset) {
    return {
        ...data,
        presets: {
            ...(data.presets || {}),
            [name]: preset,
        },
    };
}
function removePreset(data, name) {
    const presets = { ...(data.presets || {}) };
    delete presets[name];
    return { ...data, presets };
}
function autoDesc(flags) {
    const model = flags.includes("opus") ? "Opus 4.7" : "Sonnet 4.6";
    const effortMatch = flags.match(/--effort\s+(\S+)/);
    const effort = effortMatch ? `${effortMatch[1]} effort` : "auto effort";
    let mode = "default mode";
    if (flags.includes("dangerously-skip"))
        mode = "skip permissions";
    else if (flags.includes("--permission-mode plan"))
        mode = "plan mode";
    else if (flags.includes("acceptEdits"))
        mode = "accept edits";
    return `${model} · ${effort} · ${mode}`;
}
async function buildFlags() {
    console.log(`\n${utils_1.colors.bold}Model${utils_1.colors.reset}\n`);
    console.log("    1) sonnet  — Sonnet 4.6 (fast, daily driver)");
    console.log("    2) opus    — Opus 4.7 (smartest, slower)\n");
    const modelChoice = await (0, utils_1.ask)("Choice [1]:");
    const model = modelChoice === "2" ? "opus" : "sonnet";
    console.log(`\n${utils_1.colors.bold}Effort / reasoning${utils_1.colors.reset}\n`);
    console.log("    1) auto   — Claude decides");
    console.log("    2) low    — fast, minimal reasoning");
    console.log("    3) medium");
    console.log("    4) high");
    console.log("    5) max    — slowest, deepest reasoning\n");
    const effortChoice = await (0, utils_1.ask)("Choice [1]:");
    const effort = effortChoice === "2"
        ? "--effort low"
        : effortChoice === "3"
            ? "--effort medium"
            : effortChoice === "4"
                ? "--effort high"
                : effortChoice === "5"
                    ? "--effort max"
                    : "";
    console.log(`\n${utils_1.colors.bold}Permission mode${utils_1.colors.reset}\n`);
    console.log("    1) default          — normal approvals");
    console.log("    2) skip (yolo)      — --dangerously-skip-permissions");
    console.log("    3) plan             — plan-only, no execution");
    console.log("    4) acceptEdits      — auto-accept file edits, approve shell\n");
    const modeChoice = await (0, utils_1.ask)("Choice [1]:");
    const mode = modeChoice === "2"
        ? "--dangerously-skip-permissions"
        : modeChoice === "3"
            ? "--permission-mode plan"
            : modeChoice === "4"
                ? "--permission-mode acceptEdits"
                : "--permission-mode default";
    return [`--model ${model}`, effort, mode].filter(Boolean).join(" ");
}
function showUserPresets(data) {
    const names = presetNames(data);
    if (!names.length) {
        console.log(`    ${utils_1.colors.dim}(no user presets — built-ins are active)${utils_1.colors.reset}`);
        return;
    }
    names.forEach((name, index) => {
        const preset = data.presets?.[name] || {};
        const label = `${name}${preset.alias ? ` (${preset.alias})` : ""}`;
        console.log(`    ${index + 1}) ${label.padEnd(22)} ${utils_1.colors.dim}${preset.flags || ""}${utils_1.colors.reset}`);
        if (preset.description)
            console.log(`       ${"".padEnd(22)} ${utils_1.colors.dim}${preset.description}${utils_1.colors.reset}`);
    });
}
async function addPreset() {
    let data = (0, config_1.readFileConfig)();
    console.log(`\n${utils_1.colors.bold}Add preset${utils_1.colors.reset}\n`);
    const name = await (0, utils_1.ask)("Preset name (e.g. 'myfast'):");
    if (!name) {
        (0, utils_1.warn)("Cancelled.");
        return;
    }
    if (data.presets?.[name]) {
        (0, utils_1.warn)(`Preset '${name}' already exists. Use Edit to modify it.`);
        return;
    }
    const flags = await buildFlags();
    const generated = autoDesc(flags);
    console.log(`\n  Auto-description: ${utils_1.colors.dim}${generated}${utils_1.colors.reset}`);
    const desc = (await (0, utils_1.ask)("Custom description [enter to keep]:")) || generated;
    let alias = await (0, utils_1.ask)("Single-char alias [enter to skip]:");
    if (alias.length > 1)
        alias = alias.slice(0, 1);
    const prompt = await (0, utils_1.ask)("System-prompt addendum [enter to skip]:");
    const mcp = await (0, utils_1.ask)("MCP config path [enter to skip]:");
    console.log("\n  Preview:");
    console.log(`    name:  ${name}`);
    console.log(`    flags: ${flags}`);
    console.log(`    desc:  ${desc}`);
    if (alias)
        console.log(`    alias: ${alias}`);
    if (prompt)
        console.log(`    prompt: ${prompt}`);
    if (mcp)
        console.log(`    mcp:   ${mcp}`);
    console.log("");
    const confirm = await (0, utils_1.ask)("Save? [Y/n]:");
    if (confirm.toLowerCase() === "n") {
        (0, utils_1.warn)("Cancelled.");
        return;
    }
    data = upsertPreset(data, name, {
        flags,
        description: desc,
        ...(alias ? { alias } : {}),
        ...(prompt ? { prompt } : {}),
        ...(mcp ? { mcp } : {}),
    });
    (0, config_1.writeFileConfig)(data);
    (0, utils_1.ok)(`Preset '${name}' added.`);
}
async function editPreset() {
    let data = (0, config_1.readFileConfig)();
    const names = presetNames(data);
    if (!names.length) {
        (0, utils_1.warn)("No user presets to edit.");
        return;
    }
    console.log(`\n${utils_1.colors.bold}Edit preset${utils_1.colors.reset}\n`);
    names.forEach((name, index) => console.log(`    ${index + 1}) ${name}`));
    console.log("");
    const index = Number(await (0, utils_1.ask)("Preset number:"));
    if (!Number.isInteger(index) || index < 1 || index > names.length) {
        (0, utils_1.warn)("Invalid number.");
        return;
    }
    const name = names[index - 1];
    const preset = { ...(data.presets?.[name] || {}) };
    console.log(`\n  Editing '${name}'`);
    const rebuild = await (0, utils_1.ask)("Rebuild flags interactively? [Y/n]:");
    if (rebuild.toLowerCase() !== "n") {
        preset.flags = await buildFlags();
    }
    else {
        console.log(`  Current flags: ${utils_1.colors.dim}${preset.flags || ""}${utils_1.colors.reset}`);
        const flags = await (0, utils_1.ask)("New flags [enter to keep]:");
        if (flags)
            preset.flags = flags;
    }
    console.log(`  Current description: ${utils_1.colors.dim}${preset.description || ""}${utils_1.colors.reset}`);
    const desc = await (0, utils_1.ask)("New description [enter to keep]:");
    if (desc)
        preset.description = desc;
    console.log(`  Current alias: ${utils_1.colors.dim}${preset.alias || "(none)"}${utils_1.colors.reset}`);
    const alias = await (0, utils_1.ask)("New alias [enter to keep, - to clear]:");
    if (alias === "-")
        delete preset.alias;
    else if (alias)
        preset.alias = alias.slice(0, 1);
    console.log(`  Current prompt: ${utils_1.colors.dim}${preset.prompt || "(none)"}${utils_1.colors.reset}`);
    const prompt = await (0, utils_1.ask)("New prompt [enter to keep, - to clear]:");
    if (prompt === "-")
        delete preset.prompt;
    else if (prompt)
        preset.prompt = prompt;
    console.log(`  Current mcp: ${utils_1.colors.dim}${preset.mcp || "(none)"}${utils_1.colors.reset}`);
    const mcp = await (0, utils_1.ask)("New mcp path [enter to keep, - to clear]:");
    if (mcp === "-")
        delete preset.mcp;
    else if (mcp)
        preset.mcp = mcp;
    data = upsertPreset(data, name, preset);
    (0, config_1.writeFileConfig)(data);
    (0, utils_1.ok)(`Preset '${name}' updated.`);
}
async function deletePreset() {
    let data = (0, config_1.readFileConfig)();
    const names = presetNames(data);
    if (!names.length) {
        (0, utils_1.warn)("No user presets to remove.");
        return;
    }
    console.log(`\n${utils_1.colors.bold}Remove preset${utils_1.colors.reset}\n`);
    names.forEach((name, index) => console.log(`    ${index + 1}) ${name}`));
    console.log("");
    const index = Number(await (0, utils_1.ask)("Preset number to remove:"));
    if (!Number.isInteger(index) || index < 1 || index > names.length) {
        (0, utils_1.warn)("Invalid number.");
        return;
    }
    const name = names[index - 1];
    const confirm = await (0, utils_1.ask)(`Remove '${name}'? [y/N]:`);
    if (confirm.toLowerCase() !== "y") {
        (0, utils_1.warn)("Cancelled.");
        return;
    }
    data = removePreset(data, name);
    (0, config_1.writeFileConfig)(data);
    (0, utils_1.ok)(`Preset '${name}' removed.`);
}
async function managePresets() {
    while (true) {
        const data = (0, config_1.readFileConfig)();
        const paths = (0, utils_1.getPaths)();
        console.log(`\n${utils_1.colors.bold}Preset manager${utils_1.colors.reset}\n`);
        console.log(`  ${utils_1.colors.dim}User presets in ${paths.configFile}:${utils_1.colors.reset}\n`);
        showUserPresets(data);
        console.log("\n    a) Add preset");
        console.log("    e) Edit preset");
        console.log("    r) Remove preset");
        console.log("    q) Back / quit\n");
        const action = (await (0, utils_1.ask)("Choice:")).toLowerCase();
        if (action === "a")
            await addPreset();
        else if (action === "e")
            await editPreset();
        else if (action === "r")
            await deletePreset();
        else if (action === "q" || action === "")
            return;
        else
            (0, utils_1.warn)("Unknown choice.");
    }
}
async function manageUx() {
    const data = (0, config_1.readFileConfig)();
    const currentOrder = data.ux?.order?.join(" ") || "";
    let defaultPreset = data.ux?.default || "standard";
    let remap = data.ux?.remap || "warp";
    console.log(`\n${utils_1.colors.bold}UX settings${utils_1.colors.reset}\n`);
    console.log("  Current:");
    console.log(`    Order:   ${utils_1.colors.dim}${currentOrder || "(alphabetical)"}${utils_1.colors.reset}`);
    console.log(`    Default: ${utils_1.colors.dim}${defaultPreset}${utils_1.colors.reset}`);
    console.log(`    Remap:   ${utils_1.colors.dim}${remap}${utils_1.colors.reset}\n`);
    console.log(`${utils_1.colors.bold}Picker order${utils_1.colors.reset} — space-separated preset names`);
    console.log(`${utils_1.colors.dim}Example: plan max standard quick${utils_1.colors.reset}`);
    const order = (await (0, utils_1.ask)(`Order [${currentOrder}]:`)) || currentOrder;
    const newDefault = await (0, utils_1.ask)(`Default [${defaultPreset}]:`);
    if (newDefault)
        defaultPreset = newDefault;
    console.log(`\n${utils_1.colors.bold}Remap 'claude' → 'claudes'${utils_1.colors.reset}`);
    console.log(`    1) warp  — Warp terminal only ${utils_1.colors.dim}(recommended)${utils_1.colors.reset}`);
    console.log("    2) all   — every terminal");
    console.log("    3) none  — never\n");
    const remapNumber = remap === "warp" ? "1" : remap === "all" ? "2" : "3";
    const remapChoice = await (0, utils_1.ask)(`Remap [${remapNumber}]:`);
    if (remapChoice === "1")
        remap = "warp";
    else if (remapChoice === "2")
        remap = "all";
    else if (remapChoice === "3")
        remap = "none";
    (0, config_1.writeFileConfig)({
        ...data,
        ux: {
            order: order.split(/\s+/).filter(Boolean),
            default: defaultPreset,
            remap,
        },
    });
    (0, utils_1.ok)("Updated UX settings.");
}
async function configure(args) {
    const target = args[0] || "";
    if (target === "presets") {
        await managePresets();
        return 0;
    }
    if (target === "ux") {
        await manageUx();
        return 0;
    }
    const paths = (0, utils_1.getPaths)();
    console.log(`\n${utils_1.colors.bold}claudes config${utils_1.colors.reset}\n`);
    console.log(`  Config: ${utils_1.colors.dim}${paths.configFile}${utils_1.colors.reset}\n`);
    console.log("    1) Manage presets");
    console.log("    2) UX settings (order, default, remap)");
    console.log("    q) Quit\n");
    const choice = (await (0, utils_1.ask)("Choice:")).toLowerCase();
    if (choice === "1" || choice === "presets")
        await managePresets();
    else if (choice === "2" || choice === "ux")
        await manageUx();
    else if (choice !== "q" && choice !== "")
        (0, utils_1.warn)("Unknown choice.");
    return 0;
}
function builtInNames() {
    return config_1.builtInPresets.map((preset) => preset.name);
}
