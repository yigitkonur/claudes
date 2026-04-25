"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.recommendedConfig = recommendedConfig;
exports.install = install;
const node_fs_1 = __importDefault(require("node:fs"));
const node_path_1 = __importDefault(require("node:path"));
const node_child_process_1 = require("node:child_process");
const configure_1 = require("./configure");
const config_1 = require("./config");
const utils_1 = require("./utils");
function commandExists(name) {
    const result = (0, node_child_process_1.spawnSync)("zsh", ["-lc", `command -v ${name} >/dev/null 2>&1`], { stdio: "ignore" });
    return result.status === 0;
}
function copyRuntime() {
    const root = (0, utils_1.packageRoot)();
    const paths = (0, utils_1.getPaths)();
    const distSrc = node_path_1.default.join(root, "dist");
    if (!node_fs_1.default.existsSync(distSrc)) {
        throw new Error(`Compiled runtime not found at ${distSrc}. Run: npm run build`);
    }
    (0, utils_1.ensureDir)(paths.v2Dir, "v2 install directory");
    node_fs_1.default.rmSync(node_path_1.default.join(paths.v2Dir, "dist"), { recursive: true, force: true });
    node_fs_1.default.cpSync(distSrc, node_path_1.default.join(paths.v2Dir, "dist"), { recursive: true });
    for (const file of ["package.json", "README.md", "CHANGELOG.md", "LICENSE"]) {
        const src = node_path_1.default.join(root, file);
        if (node_fs_1.default.existsSync(src))
            (0, utils_1.copyFile)(src, node_path_1.default.join(paths.v2Dir, file));
    }
}
function zshCoreContent() {
    const paths = (0, utils_1.getPaths)();
    return `# claudes v2 — https://github.com/yigitkonur/claudes
_claudes_node=${JSON.stringify(node_path_1.default.join(paths.v2Dir, "dist", "cli.js"))}
_claudes_define_command() {
  local _name="$1"
  case "$_name" in
    claude|claudes|ccp|claude-preset)
      unalias "$_name" 2>/dev/null
      eval "function $_name { command node \\"$_claudes_node\\" \\"\\$@\\"; }"
      ;;
  esac
}
for _claudes_cmd in $(command node "$_claudes_node" __commands 2>/dev/null || echo claudes); do
  _claudes_define_command "$_claudes_cmd"
done
unset _claudes_cmd
unfunction _claudes_define_command 2>/dev/null
`;
}
function zshUxContent() {
    const paths = (0, utils_1.getPaths)();
    return `# claudes v2 UX layer — https://github.com/yigitkonur/claudes
_claudes_node=${JSON.stringify(node_path_1.default.join(paths.v2Dir, "dist", "cli.js"))}

_claudes_by_pos() {
  local n="$1"; shift
  command node "$_claudes_node" __pos "$n" "$@"
}

for _cpos in 1 2 3 4 5 6 7 8 9; do
  eval "claude\${_cpos}() { _claudes_by_pos \${_cpos} \\"\\$@\\"; }"
done
unset _cpos

`;
}
function installShellFile(name, content, linkName) {
    const paths = (0, utils_1.getPaths)();
    const target = node_path_1.default.join(paths.v2Dir, name);
    node_fs_1.default.writeFileSync(target, content, "utf8");
    if (node_fs_1.default.existsSync(paths.zshrcDir) && node_fs_1.default.statSync(paths.zshrcDir).isDirectory()) {
        const link = node_path_1.default.join(paths.zshrcDir, linkName);
        node_fs_1.default.rmSync(link, { force: true });
        node_fs_1.default.symlinkSync(target, link);
        (0, utils_1.ok)(`Linked to ${link}`);
        return;
    }
    const marker = `# ${name.replace(".zsh", "")} — https://github.com/yigitkonur/claudes`;
    const sourceLine = `[ -f "${target}" ] && source "${target}"`;
    const existing = node_fs_1.default.existsSync(paths.zshrc) ? node_fs_1.default.readFileSync(paths.zshrc, "utf8") : "";
    if (!existing.includes(marker)) {
        node_fs_1.default.appendFileSync(paths.zshrc, `\n${marker}\n${sourceLine}\n`, "utf8");
        (0, utils_1.ok)(`Appended ${name} to ${paths.zshrc}`);
    }
    else {
        (0, utils_1.ok)(`Already sourced from ${paths.zshrc}`);
    }
}
function dumpZshConfig(file, script) {
    const result = (0, node_child_process_1.spawnSync)("zsh", ["-c", script, "claudes-migrate", file], {
        encoding: "utf8",
    });
    return result.status === 0 ? result.stdout : "";
}
function migrateLegacy() {
    const paths = (0, utils_1.getPaths)();
    const oldPresets = node_path_1.default.join(paths.configDir, "presets.zsh");
    const oldUx = node_path_1.default.join(paths.configDir, "ux-settings.zsh");
    if (!node_fs_1.default.existsSync(oldPresets) && !node_fs_1.default.existsSync(oldUx))
        return null;
    (0, utils_1.warn)("Old config files found (.zsh format).");
    const data = { ux: {}, presets: {}, remove_builtins: [] };
    if (node_fs_1.default.existsSync(oldPresets)) {
        const out = dumpZshConfig(oldPresets, 'source "$1"; for k in ${(ko)CLAUDES_PRESETS}; do printf "PRESET\\t%s\\t%s\\n" "$k" "${CLAUDES_PRESETS[$k]}"; done; for k in ${(ko)CLAUDES_DESCRIPTIONS}; do printf "DESC\\t%s\\t%s\\n" "$k" "${CLAUDES_DESCRIPTIONS[$k]}"; done; for k in ${(ko)CLAUDES_ALIASES}; do printf "ALIAS\\t%s\\t%s\\n" "$k" "${CLAUDES_ALIASES[$k]}"; done');
        for (const line of out.split(/\r?\n/)) {
            const [kind, key, value] = line.split("\t");
            if (!kind || !key || value === undefined)
                continue;
            data.presets ||= {};
            if (kind === "PRESET")
                data.presets[key] = { ...(data.presets[key] || {}), flags: value };
            if (kind === "DESC")
                data.presets[key] = { ...(data.presets[key] || {}), description: value };
            if (kind === "ALIAS")
                data.presets[value] = { ...(data.presets[value] || {}), alias: key };
        }
    }
    if (node_fs_1.default.existsSync(oldUx)) {
        const out = dumpZshConfig(oldUx, 'source "$1"; echo "ORDER:${CLAUDES_ORDER[*]:-}"; echo "DEFAULT:${CLAUDES_DEFAULT:-standard}"; echo "REMAP:${CLAUDES_REMAP_CLAUDE:-warp}"');
        for (const line of out.split(/\r?\n/)) {
            if (line.startsWith("ORDER:")) {
                const order = line.slice(6).trim();
                if (order)
                    data.ux.order = order.split(/\s+/);
            }
            if (line.startsWith("DEFAULT:"))
                data.ux.default = line.slice(8).trim() || "standard";
            if (line.startsWith("REMAP:")) {
                const remap = line.slice(6).trim();
                if (remap === "warp" || remap === "all" || remap === "none")
                    data.ux.remap = remap;
            }
        }
    }
    return data;
}
function recommendedConfig() {
    return {
        ux: { order: ["plan", "max", "standard", "quick"], default: "standard", remap: "warp" },
        presets: {
            plan: {
                flags: "--model opus[1m] --effort max --permission-mode plan",
                description: "Opus 4.7 · 1M ctx · max effort · plan mode",
                alias: "p",
            },
            max: {
                flags: "--model opus[1m] --effort max --dangerously-skip-permissions",
                description: "Opus 4.7 · 1M ctx · max effort · skip permissions · yolo",
                alias: "m",
            },
            standard: {
                flags: "--model sonnet --dangerously-skip-permissions",
                description: "Sonnet 4.6 · auto effort · skip permissions · daily",
                alias: "s",
            },
            quick: {
                flags: "--model sonnet --effort low --dangerously-skip-permissions",
                description: "Sonnet 4.6 · low effort · skip permissions · fast/cheap",
                alias: "q",
            },
        },
        remove_builtins: ["research"],
    };
}
function mergeUx(data, order, defaultPreset, remap, commands) {
    return {
        ...data,
        ux: {
            ...(data.ux || {}),
            ...(order.length ? { order } : {}),
            default: defaultPreset,
            remap,
            commands: (0, config_1.normalizeShellCommands)(commands),
        },
    };
}
function parseShellCommandSelection(value) {
    const byNumber = {
        "1": "claude",
        "2": "claudes",
        "3": "ccp",
        "4": "claude-preset",
    };
    const normalized = value
        .split(/[\s,]+/)
        .map((part) => byNumber[part] || part.trim())
        .filter(Boolean);
    return (0, config_1.normalizeShellCommands)(normalized);
}
async function install() {
    const paths = (0, utils_1.getPaths)();
    console.log("");
    console.log(`${utils_1.colors.bold}  claudes${utils_1.colors.reset} — Claude Code preset picker`);
    console.log(`${utils_1.colors.dim}  https://github.com/yigitkonur/claudes${utils_1.colors.reset}\n`);
    if (!commandExists("zsh"))
        throw new Error("zsh is required. Install zsh first.");
    (0, utils_1.step)("Step 1/4 — Core install");
    (0, utils_1.ensureDir)(paths.installDir, "install directory");
    (0, utils_1.ensureDir)(paths.configDir, "config directory");
    copyRuntime();
    (0, utils_1.ok)(`Scripts at ${paths.v2Dir}/`);
    const migrated = migrateLegacy();
    if (migrated && !node_fs_1.default.existsSync(paths.configFile)) {
        const doMigrate = await (0, utils_1.ask)("Migrate to claudes.yaml? [Y/n]:");
        if (doMigrate.toLowerCase() !== "n") {
            (0, config_1.writeFileConfig)(migrated);
            (0, utils_1.ok)(`Migrated to ${paths.configFile}`);
        }
    }
    (0, utils_1.step)("Step 2/4 — Commands and UX");
    console.log("  Choose which shell commands should open the preset picker:\n");
    console.log(`    1) claude         ${utils_1.colors.dim}overrides the raw claude command; presets still launch the real binary${utils_1.colors.reset}`);
    console.log(`    2) claudes        ${utils_1.colors.dim}current project command${utils_1.colors.reset}`);
    console.log(`    3) ccp            ${utils_1.colors.dim}short for Claude Code presets${utils_1.colors.reset}`);
    console.log(`    4) claude-preset  ${utils_1.colors.dim}singular compatibility alias${utils_1.colors.reset}\n`);
    console.log(`  ${utils_1.colors.dim}Enter numbers or names separated by spaces/commas.${utils_1.colors.reset}`);
    const commandChoice = await (0, utils_1.ask)("Commands [1 2 3 4]:");
    const selectedCommands = parseShellCommandSelection(commandChoice || "1 2 3 4");
    (0, utils_1.ok)(`Shell commands: ${selectedCommands.join(", ")}`);
    installShellFile("claudes.zsh", zshCoreContent(), "90-claudes.zsh");
    console.log("");
    console.log("  The UX layer adds:");
    console.log(`    • ${utils_1.colors.bold}Single-key picker${utils_1.colors.reset}  — 1/2/3 or p/s/q, no Enter needed`);
    console.log(`    • ${utils_1.colors.bold}Enter default${utils_1.colors.reset}      — bare Enter picks your chosen default`);
    console.log(`    • ${utils_1.colors.bold}claude1..claude9${utils_1.colors.reset}  — jump to preset N from the CLI`);
    console.log(`    • ${utils_1.colors.bold}selected aliases${utils_1.colors.reset} — ${selectedCommands.join(", ")} open this picker\n`);
    const wantUx = await (0, utils_1.ask)("Install enhanced UX? [Y/n]:");
    const installUx = wantUx.toLowerCase() !== "n";
    let uxOrder = [];
    let uxDefault = "standard";
    const uxRemap = selectedCommands.includes("claude") ? "all" : "none";
    if (installUx) {
        console.log(`\n  ${utils_1.colors.bold}Default preset${utils_1.colors.reset} — bare Enter selects:`);
        const defaultChoice = await (0, utils_1.ask)("Default [standard]:");
        if (defaultChoice)
            uxDefault = defaultChoice;
        installShellFile("ux.zsh", zshUxContent(), "91-claudes-ux.zsh");
    }
    (0, utils_1.step)("Step 3/4 — Presets");
    if (node_fs_1.default.existsSync(paths.configFile)) {
        (0, utils_1.ok)(`Using existing ${paths.configFile}`);
    }
    else {
        console.log("  Choose a preset scheme:\n");
        console.log(`    ${utils_1.colors.bold}1) Recommended${utils_1.colors.reset}  4-slot scheme:`);
        console.log(`       ${utils_1.colors.dim}  plan     · Opus max + plan mode${utils_1.colors.reset}`);
        console.log(`       ${utils_1.colors.dim}  max      · Opus max + skip permissions (yolo)${utils_1.colors.reset}`);
        console.log(`       ${utils_1.colors.dim}  standard · Sonnet auto + skip permissions (daily)${utils_1.colors.reset}`);
        console.log(`       ${utils_1.colors.dim}  quick    · Sonnet low + skip permissions (fast)${utils_1.colors.reset}\n`);
        console.log(`    ${utils_1.colors.bold}2) Built-in defaults${utils_1.colors.reset}  standard / quick / plan / research`);
        console.log(`    ${utils_1.colors.bold}3) Custom${utils_1.colors.reset}             configure interactively now`);
        console.log(`    ${utils_1.colors.bold}4) Skip${utils_1.colors.reset}               configure later via \`${selectedCommands[0]} config\`\n`);
        const presetChoice = await (0, utils_1.ask)("Choice [1]:");
        if (presetChoice === "" || presetChoice === "1") {
            const config = recommendedConfig();
            uxOrder = ["plan", "max", "standard", "quick"];
            (0, config_1.writeFileConfig)(config);
            (0, utils_1.ok)(`Wrote recommended presets to ${paths.configFile}`);
        }
        else if (presetChoice === "2") {
            (0, utils_1.info)("Keeping built-in defaults.");
        }
        else if (presetChoice === "3") {
            (0, utils_1.info)("Launching interactive preset configurator...");
            await (0, configure_1.configure)(["presets"]);
        }
        else if (presetChoice === "4") {
            (0, utils_1.info)(`Skipped. Edit ${paths.configFile} or run: ${selectedCommands[0]} config`);
        }
        else {
            (0, utils_1.warn)("Unknown choice — keeping built-in defaults.");
        }
    }
    (0, utils_1.step)("Step 4/4 — Finishing up");
    if (installUx) {
        const fileConfig = node_fs_1.default.existsSync(paths.configFile) ? (0, config_1.readFileConfig)() : {};
        (0, config_1.writeFileConfig)(mergeUx(fileConfig, uxOrder, uxDefault, uxRemap, selectedCommands));
        (0, utils_1.ok)(`UX settings merged into ${paths.configFile}`);
    }
    else {
        const fileConfig = node_fs_1.default.existsSync(paths.configFile) ? (0, config_1.readFileConfig)() : {};
        (0, config_1.writeFileConfig)(mergeUx(fileConfig, [], uxDefault, uxRemap, selectedCommands));
        (0, utils_1.ok)(`Shell command settings merged into ${paths.configFile}`);
    }
    if (node_fs_1.default.existsSync(paths.configFile)) {
        (0, config_1.writeCache)((0, config_1.loadRuntimeConfig)());
        (0, utils_1.ok)(`Cache warmed: ${paths.cacheFile}`);
    }
    console.log(`\n${utils_1.colors.green}${utils_1.colors.bold}  Done!${utils_1.colors.reset}\n`);
    console.log(`  Restart shell or:  ${utils_1.colors.dim}exec zsh${utils_1.colors.reset}`);
    console.log(`  Open picker:       ${utils_1.colors.dim}${selectedCommands.join(" / ")}${utils_1.colors.reset}`);
    console.log(`  List presets:      ${utils_1.colors.dim}${selectedCommands[0]} list${utils_1.colors.reset}`);
    console.log(`  Manage presets:    ${utils_1.colors.dim}${selectedCommands[0]} config${utils_1.colors.reset}`);
    console.log(`  Config file:       ${utils_1.colors.dim}${paths.configFile}${utils_1.colors.reset}\n`);
    return 0;
}
