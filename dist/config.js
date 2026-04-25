"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.defaultShellCommands = exports.allowedShellCommands = exports.builtInPresets = void 0;
exports.normalizeShellCommands = normalizeShellCommands;
exports.parseYaml = parseYaml;
exports.renderYaml = renderYaml;
exports.readFileConfig = readFileConfig;
exports.writeFileConfig = writeFileConfig;
exports.loadRuntimeConfig = loadRuntimeConfig;
exports.orderedPresets = orderedPresets;
exports.resolvePreset = resolvePreset;
exports.presetByIndex = presetByIndex;
exports.writeCache = writeCache;
const node_fs_1 = __importDefault(require("node:fs"));
const node_path_1 = __importDefault(require("node:path"));
const utils_1 = require("./utils");
exports.builtInPresets = [
    {
        name: "standard",
        flags: "--model sonnet --effort max --permission-mode default",
        description: "Sonnet 4.6 · max effort · daily coding work",
        alias: "s",
        builtin: true,
    },
    {
        name: "quick",
        flags: "--model sonnet --effort low --permission-mode default",
        description: "Sonnet 4.6 · low effort · fast/cheap edits",
        alias: "q",
        builtin: true,
    },
    {
        name: "plan",
        flags: "--model opus[1m] --effort max --permission-mode plan",
        description: "Opus 4.7 · 1M ctx · max effort · plan mode · deep thinking",
        alias: "p",
        builtin: true,
    },
    {
        name: "research",
        flags: "--model opus[1m] --effort max --permission-mode default",
        description: "Opus 4.7 · 1M ctx · max effort · direct · explore/review",
        alias: "r",
        builtin: true,
    },
];
exports.allowedShellCommands = ["claude", "claudes", "ccp", "claude-preset"];
exports.defaultShellCommands = ["claudes"];
function normalizeShellCommands(commands) {
    const allowed = new Set(exports.allowedShellCommands);
    const result = [];
    for (const command of commands || []) {
        const trimmed = command.trim();
        if (allowed.has(trimmed) && !result.includes(trimmed))
            result.push(trimmed);
    }
    return result.length ? result : [...exports.defaultShellCommands];
}
function stripInlineComment(value) {
    let single = false;
    let double = false;
    for (let i = 0; i < value.length; i += 1) {
        const char = value[i];
        if (char === "'" && !double)
            single = !single;
        else if (char === '"' && !single)
            double = !double;
        else if (char === "#" && !single && !double)
            return value.slice(0, i).trimEnd();
    }
    return value;
}
function unquote(value) {
    const trimmed = value.trim();
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
        return trimmed.slice(1, -1).replace(/\\"/g, '"').replace(/\\n/g, "\n");
    }
    return trimmed;
}
function parseFlowList(value) {
    const trimmed = value.trim();
    if (!trimmed.startsWith("[") || !trimmed.endsWith("]"))
        return null;
    const inner = trimmed.slice(1, -1).trim();
    if (!inner)
        return [];
    const items = [];
    let current = "";
    let quote = null;
    for (let i = 0; i < inner.length; i += 1) {
        const char = inner[i];
        if ((char === "'" || char === '"') && quote === null) {
            quote = char;
            current += char;
            continue;
        }
        if (char === quote) {
            quote = null;
            current += char;
            continue;
        }
        if (char === "," && quote === null) {
            items.push(unquote(current.trim()));
            current = "";
            continue;
        }
        current += char;
    }
    if (current.trim())
        items.push(unquote(current.trim()));
    return items;
}
function indentOf(line) {
    return line.length - line.trimStart().length;
}
function parseYaml(text) {
    const result = {};
    let topKey = "";
    let presetName = "";
    let lowKey = "";
    let blockList = null;
    for (const raw of text.split(/\r?\n/)) {
        const line = raw.trimEnd();
        const strippedRaw = line.trimStart();
        if (!strippedRaw || strippedRaw.startsWith("#")) {
            blockList = null;
            continue;
        }
        const ind = indentOf(line);
        const stripped = stripInlineComment(strippedRaw);
        if (stripped.startsWith("- ")) {
            if (blockList === "remove_builtins") {
                result.remove_builtins ||= [];
                result.remove_builtins.push(unquote(stripped.slice(2).trim()));
            }
            continue;
        }
        blockList = null;
        const colon = stripped.indexOf(":");
        if (colon < 0)
            continue;
        const key = stripped.slice(0, colon).trim();
        const rest = stripped.slice(colon + 1).trim();
        if (ind === 0) {
            topKey = key;
            presetName = "";
            lowKey = "";
            if (key === "ux")
                result.ux ||= {};
            else if (key === "presets")
                result.presets ||= {};
            else if (key === "remove_builtins") {
                const parsed = parseFlowList(rest);
                result.remove_builtins = parsed || [];
                if (!rest)
                    blockList = "remove_builtins";
            }
            continue;
        }
        if (ind === 2 && topKey === "ux") {
            result.ux ||= {};
            const parsed = parseFlowList(rest);
            if (key === "order")
                result.ux.order = parsed || rest.split(/\s+/).filter(Boolean);
            if (key === "commands")
                result.ux.commands = parsed || rest.split(/\s+/).filter(Boolean);
            if (key === "default")
                result.ux.default = unquote(rest);
            if (key === "remap") {
                const remap = unquote(rest);
                if (remap === "warp" || remap === "all" || remap === "none")
                    result.ux.remap = remap;
            }
            continue;
        }
        if (ind === 2 && topKey === "presets") {
            result.presets ||= {};
            presetName = key;
            lowKey = "";
            result.presets[presetName] ||= {};
            continue;
        }
        if (ind === 4 && topKey === "presets" && presetName) {
            const preset = result.presets?.[presetName] || {};
            lowKey = key;
            if (key === "env" && !rest) {
                preset.env ||= {};
            }
            else if (key === "env") {
                preset.env ||= {};
            }
            else {
                preset[key] = unquote(rest);
            }
            result.presets[presetName] = preset;
            continue;
        }
        if (ind === 6 && topKey === "presets" && presetName && lowKey === "env") {
            const preset = result.presets?.[presetName] || {};
            preset.env ||= {};
            preset.env[key] = unquote(rest);
            result.presets[presetName] = preset;
        }
    }
    return result;
}
function yamlQuote(value) {
    return `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n")}"`;
}
function renderYaml(data) {
    const lines = ["# ~/.config/claudes/claudes.yaml", "# edit directly or run: claudes config", ""];
    const ux = data.ux || {};
    lines.push("ux:");
    if (ux.order?.length)
        lines.push(`  order: [${ux.order.join(", ")}]`);
    lines.push(`  default: ${ux.default || "standard"}`);
    lines.push(`  remap: ${ux.remap || "warp"}  # warp | all | none`);
    lines.push(`  commands: [${normalizeShellCommands(ux.commands).join(", ")}]`);
    lines.push("");
    lines.push("presets:");
    const presets = data.presets || {};
    const names = Object.keys(presets);
    if (!names.length)
        lines.push("  # no user presets — built-ins (standard, quick, plan, research) are active");
    for (const name of names) {
        const preset = presets[name] || {};
        lines.push(`  ${name}:`);
        if (preset.flags)
            lines.push(`    flags: ${yamlQuote(preset.flags)}`);
        if (preset.description)
            lines.push(`    description: ${yamlQuote(preset.description)}`);
        if (preset.alias)
            lines.push(`    alias: ${preset.alias}`);
        if (preset.prompt)
            lines.push(`    prompt: ${yamlQuote(preset.prompt)}`);
        if (preset.mcp)
            lines.push(`    mcp: ${yamlQuote(preset.mcp)}`);
        if (preset.env && Object.keys(preset.env).length) {
            lines.push("    env:");
            for (const [key, value] of Object.entries(preset.env)) {
                lines.push(`      ${key}: ${yamlQuote(String(value))}`);
            }
        }
        lines.push("");
    }
    const remove = data.remove_builtins || [];
    if (remove.length) {
        lines.push("remove_builtins:");
        for (const name of remove)
            lines.push(`  - ${name}`);
    }
    else {
        lines.push("remove_builtins: []");
    }
    lines.push("");
    return lines.join("\n");
}
function readFileConfig() {
    const paths = (0, utils_1.getPaths)();
    if (!node_fs_1.default.existsSync(paths.configFile))
        return {};
    return parseYaml(node_fs_1.default.readFileSync(paths.configFile, "utf8"));
}
function writeFileConfig(data) {
    const paths = (0, utils_1.getPaths)();
    (0, utils_1.ensureDir)(paths.configDir, "config directory");
    node_fs_1.default.writeFileSync(paths.configFile, renderYaml(data), "utf8");
    try {
        node_fs_1.default.rmSync(paths.cacheFile, { force: true });
    }
    catch {
        // cache invalidation is best-effort
    }
}
function runtimePreset(name, cfg, builtin) {
    if (!cfg.flags)
        return null;
    return {
        name,
        flags: cfg.flags,
        description: cfg.description || "",
        alias: cfg.alias || undefined,
        prompt: cfg.prompt || undefined,
        mcp: cfg.mcp || undefined,
        env: cfg.env || undefined,
        builtin,
    };
}
function loadRuntimeConfig() {
    const file = readFileConfig();
    const presets = new Map();
    const aliases = new Map();
    for (const preset of exports.builtInPresets) {
        presets.set(preset.name, { ...preset });
        if (preset.alias)
            aliases.set(preset.alias, preset.name);
    }
    for (const name of file.remove_builtins || []) {
        presets.delete(name);
        for (const [alias, target] of aliases.entries()) {
            if (target === name)
                aliases.delete(alias);
        }
    }
    for (const [name, cfg] of Object.entries(file.presets || {})) {
        const preset = runtimePreset(name, cfg, false);
        if (!preset)
            continue;
        presets.set(name, preset);
        if (preset.alias)
            aliases.set(preset.alias, name);
    }
    for (const [alias, target] of Array.from(aliases.entries())) {
        if (!presets.has(target))
            aliases.delete(alias);
    }
    return {
        file,
        presets,
        aliases,
        ux: {
            order: file.ux?.order || [],
            default: file.ux?.default || "standard",
            remap: file.ux?.remap || "warp",
            commands: normalizeShellCommands(file.ux?.commands),
        },
    };
}
function orderedPresets(config) {
    const used = new Set();
    const result = [];
    for (const name of config.ux.order) {
        const preset = config.presets.get(name);
        if (preset) {
            result.push(preset);
            used.add(name);
        }
    }
    const rest = Array.from(config.presets.values())
        .filter((preset) => !used.has(preset.name))
        .sort((a, b) => a.name.localeCompare(b.name));
    return result.concat(rest);
}
function resolvePreset(config, input) {
    return config.presets.get(input) || config.presets.get(config.aliases.get(input) || "") || null;
}
function presetByIndex(config, index) {
    return orderedPresets(config)[index - 1] || null;
}
function writeCache(config) {
    const paths = (0, utils_1.getPaths)();
    (0, utils_1.ensureDir)(node_path_1.default.dirname(paths.cacheFile), "config directory");
    node_fs_1.default.writeFileSync(paths.cacheFile, JSON.stringify({
        ux: config.ux,
        presets: Array.from(config.presets.values()),
        aliases: Object.fromEntries(config.aliases),
    }, null, 2), "utf8");
}
