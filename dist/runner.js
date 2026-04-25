"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.printPresets = printPresets;
exports.printHelp = printHelp;
exports.showPreset = showPreset;
exports.runPreset = runPreset;
exports.runCliPreset = runCliPreset;
exports.positionName = positionName;
exports.remapMode = remapMode;
exports.formatResult = formatResult;
const node_fs_1 = __importDefault(require("node:fs"));
const node_child_process_1 = require("node:child_process");
const config_1 = require("./config");
const utils_1 = require("./utils");
function markers(preset) {
    const marks = [];
    if (preset.flags.startsWith("fn:"))
        marks.push("fn");
    if (preset.env && Object.keys(preset.env).length)
        marks.push("+env");
    if (preset.mcp)
        marks.push("+mcp");
    if (preset.prompt)
        marks.push("+prompt");
    return marks.length ? ` [${marks.join(" ")}]` : "";
}
function reverseAlias(config) {
    const result = new Map();
    for (const [alias, target] of config.aliases.entries()) {
        if (!result.has(target))
            result.set(target, alias);
    }
    return result;
}
function printPresets(config = (0, config_1.loadRuntimeConfig)()) {
    const aliases = reverseAlias(config);
    console.log("");
    for (const [index, preset] of (0, config_1.orderedPresets)(config).entries()) {
        const alias = aliases.get(preset.name);
        const label = `${preset.name}${alias ? ` (${alias})` : ""}`;
        console.log(`    ${index + 1}) ${label.padEnd(18)} · ${preset.description}${markers(preset)}`);
    }
    console.log("");
}
function printHelp() {
    console.log(`claudes — Claude Code preset picker

USAGE
  claudes                       Interactive picker
  claudes <preset> [args...]    Run a specific preset
  claudes list                  List all presets
  claudes show <preset>         Show resolved config for a preset
  claudes config [presets|ux]   Interactive preset & UX manager
  claudes install               Install shell integration
  claudes test                  Run self tests
  claudes help                  Show this help

EXAMPLES
  claudes
  claudes standard
  claudes s "fix the bug"
  claudes plan --resume
  claudes --resume
`);
}
function showPreset(name, config = (0, config_1.loadRuntimeConfig)()) {
    const preset = (0, config_1.resolvePreset)(config, name);
    if (!preset) {
        (0, utils_1.err)(`unknown preset: ${name}`);
        return 1;
    }
    console.log(`preset:       ${preset.name}`);
    console.log(`description:  ${preset.description}`);
    console.log(`flags:        ${preset.flags}`);
    if (preset.env && Object.keys(preset.env).length) {
        console.log(`env:          ${Object.entries(preset.env).map(([k, v]) => `${k}=${v}`).join(" ")}`);
    }
    if (preset.mcp)
        console.log(`mcp-config:   ${preset.mcp}`);
    if (preset.prompt)
        console.log(`prompt:       ${preset.prompt}`);
    return 0;
}
async function choosePreset(config) {
    if (!process.stdin.isTTY) {
        (0, utils_1.err)("no preset and stdin is not a TTY — pass a preset name");
        return null;
    }
    console.log("");
    console.log("  Choose Claude preset:");
    printPresets(config);
    process.stdout.write(`  > [enter = ${config.ux.default}] `);
    const key = await (0, utils_1.readSingleKey)();
    console.log("");
    if (key === "\r" || key === "\n")
        return (0, config_1.resolvePreset)(config, config.ux.default);
    const normalized = key.toLowerCase();
    if (/^[0-9]$/.test(normalized))
        return (0, config_1.presetByIndex)(config, Number(normalized));
    return (0, config_1.resolvePreset)(config, normalized);
}
function spawnAndExit(command, args, env) {
    return new Promise((resolve) => {
        const child = (0, node_child_process_1.spawn)(command, args, {
            stdio: "inherit",
            env: env || process.env,
        });
        child.on("exit", (code, signal) => {
            if (signal)
                resolve(128);
            else
                resolve(code ?? 0);
        });
        child.on("error", (error) => {
            (0, utils_1.err)(error.message);
            resolve(1);
        });
    });
}
async function runFnPreset(preset, rest) {
    const fnName = preset.flags.slice(3);
    const script = [
        'fn="$1"',
        "shift",
        'if ! typeset -f "$fn" >/dev/null 2>&1; then echo "claudes: preset function not found: $fn" >&2; exit 1; fi',
        '"$fn" "$@"',
    ].join("; ");
    const env = { ...process.env, ...preset.env };
    console.log(`▶ ${preset.name} · ${preset.description}`);
    return await spawnAndExit("zsh", ["-ic", script, "claudes-fn", fnName, ...rest], env);
}
async function runPreset(preset, rest) {
    if (preset.flags.startsWith("fn:"))
        return await runFnPreset(preset, rest);
    const claudeBin = (0, utils_1.findExecutable)("claude");
    if (!claudeBin) {
        (0, utils_1.err)("claude binary not found in PATH");
        return 127;
    }
    let args;
    try {
        args = (0, utils_1.splitShellWords)(preset.flags);
    }
    catch (error) {
        (0, utils_1.err)(String(error instanceof Error ? error.message : error));
        return 1;
    }
    if (preset.mcp) {
        const mcpPath = (0, utils_1.expandHome)(preset.mcp);
        if (!node_fs_1.default.existsSync(mcpPath)) {
            (0, utils_1.err)(`MCP config not found for '${preset.name}': ${mcpPath}`);
            return 1;
        }
        args.push("--mcp-config", mcpPath);
    }
    if (preset.prompt)
        args.push("--append-system-prompt", preset.prompt);
    args.push(...rest);
    const env = { ...process.env, ...preset.env };
    console.log(`▶ ${preset.name} · ${preset.description}`);
    return await spawnAndExit(claudeBin, args, env);
}
async function runCliPreset(args) {
    const config = (0, config_1.loadRuntimeConfig)();
    if (!args.length) {
        const preset = await choosePreset(config);
        if (!preset)
            return 1;
        return await runPreset(preset, []);
    }
    const [first, ...rest] = args;
    const claudeBin = (0, utils_1.findExecutable)("claude");
    if (first.startsWith("-")) {
        if (!claudeBin) {
            (0, utils_1.err)("claude binary not found in PATH");
            return 127;
        }
        return await spawnAndExit(claudeBin, [first, ...rest]);
    }
    const preset = (0, config_1.resolvePreset)(config, first);
    if (!preset) {
        (0, utils_1.err)(`unknown preset '${first}' (run 'claudes list' or 'claudes help')`);
        return 1;
    }
    return await runPreset(preset, rest);
}
function positionName(index) {
    return (0, config_1.presetByIndex)((0, config_1.loadRuntimeConfig)(), index)?.name || null;
}
function remapMode() {
    return (0, config_1.loadRuntimeConfig)().ux.remap;
}
function formatResult(label, pass) {
    return `${pass ? utils_1.colors.green : utils_1.colors.red}${pass ? "[pass]" : "[FAIL]"}${utils_1.colors.reset} ${label}`;
}
