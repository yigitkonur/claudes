import fs from "node:fs";
import { FileConfig, PresetConfig, RemapMode, RuntimeConfig, RuntimePreset } from "./types";
import { getPaths, writeTextFileEnsuringParent } from "./utils";

export const builtInPresets: RuntimePreset[] = [
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

export const allowedShellCommands = ["claude", "claudes", "ccp", "claude-preset"] as const;
export const defaultShellCommands = ["claudes"];

export function normalizeShellCommands(commands: string[] | undefined): string[] {
  const allowed = new Set<string>(allowedShellCommands);
  const result: string[] = [];
  for (const command of commands || []) {
    const trimmed = command.trim();
    if (allowed.has(trimmed) && !result.includes(trimmed)) result.push(trimmed);
  }
  return result.length ? result : [...defaultShellCommands];
}

function stripInlineComment(value: string): string {
  let single = false;
  let double = false;
  for (let i = 0; i < value.length; i += 1) {
    const char = value[i];
    if (char === "'" && !double) single = !single;
    else if (char === '"' && !single) double = !double;
    else if (char === "#" && !single && !double) return value.slice(0, i).trimEnd();
  }
  return value;
}

function unquote(value: string): string {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1).replace(/\\"/g, '"').replace(/\\n/g, "\n");
  }
  return trimmed;
}

function parseFlowList(value: string): string[] | null {
  const trimmed = value.trim();
  if (!trimmed.startsWith("[") || !trimmed.endsWith("]")) return null;
  const inner = trimmed.slice(1, -1).trim();
  if (!inner) return [];
  const items: string[] = [];
  let current = "";
  let quote: "'" | '"' | null = null;
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
  if (current.trim()) items.push(unquote(current.trim()));
  return items;
}

function indentOf(line: string): number {
  return line.length - line.trimStart().length;
}

export function parseYaml(text: string): FileConfig {
  const result: FileConfig = {};
  let topKey = "";
  let presetName = "";
  let lowKey = "";
  let blockList: "remove_builtins" | null = null;

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
    if (colon < 0) continue;

    const key = stripped.slice(0, colon).trim();
    const rest = stripped.slice(colon + 1).trim();

    if (ind === 0) {
      topKey = key;
      presetName = "";
      lowKey = "";
      if (key === "ux") result.ux ||= {};
      else if (key === "presets") result.presets ||= {};
      else if (key === "remove_builtins") {
        const parsed = parseFlowList(rest);
        result.remove_builtins = parsed || [];
        if (!rest) blockList = "remove_builtins";
      }
      continue;
    }

    if (ind === 2 && topKey === "ux") {
      result.ux ||= {};
      const parsed = parseFlowList(rest);
      if (key === "order") result.ux.order = parsed || rest.split(/\s+/).filter(Boolean);
      if (key === "commands") result.ux.commands = parsed || rest.split(/\s+/).filter(Boolean);
      if (key === "default") result.ux.default = unquote(rest);
      if (key === "remap") {
        const remap = unquote(rest) as RemapMode;
        if (remap === "warp" || remap === "all" || remap === "none") result.ux.remap = remap;
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
      } else if (key === "env") {
        preset.env ||= {};
      } else {
        (preset as Record<string, unknown>)[key] = unquote(rest);
      }
      result.presets![presetName] = preset;
      continue;
    }

    if (ind === 6 && topKey === "presets" && presetName && lowKey === "env") {
      const preset = result.presets?.[presetName] || {};
      preset.env ||= {};
      preset.env[key] = unquote(rest);
      result.presets![presetName] = preset;
    }
  }

  return result;
}

function yamlQuote(value: string): string {
  return `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n")}"`;
}

export function renderYaml(data: FileConfig): string {
  const lines = ["# ~/.config/claudes/claudes.yaml", "# edit directly or run: claudes config", ""];
  const ux = data.ux || {};
  lines.push("ux:");
  if (ux.order?.length) lines.push(`  order: [${ux.order.join(", ")}]`);
  lines.push(`  default: ${ux.default || "standard"}`);
  lines.push(`  remap: ${ux.remap || "warp"}  # warp | all | none`);
  lines.push(`  commands: [${normalizeShellCommands(ux.commands).join(", ")}]`);
  lines.push("");
  lines.push("presets:");
  const presets = data.presets || {};
  const names = Object.keys(presets);
  if (!names.length) lines.push("  # no user presets — built-ins (standard, quick, plan, research) are active");
  for (const name of names) {
    const preset = presets[name] || {};
    lines.push(`  ${name}:`);
    if (preset.flags) lines.push(`    flags: ${yamlQuote(preset.flags)}`);
    if (preset.description) lines.push(`    description: ${yamlQuote(preset.description)}`);
    if (preset.alias) lines.push(`    alias: ${preset.alias}`);
    if (preset.prompt) lines.push(`    prompt: ${yamlQuote(preset.prompt)}`);
    if (preset.mcp) lines.push(`    mcp: ${yamlQuote(preset.mcp)}`);
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
    for (const name of remove) lines.push(`  - ${name}`);
  } else {
    lines.push("remove_builtins: []");
  }
  lines.push("");
  return lines.join("\n");
}

export function readFileConfig(): FileConfig {
  const paths = getPaths();
  if (!fs.existsSync(paths.configFile)) return {};
  return parseYaml(fs.readFileSync(paths.configFile, "utf8"));
}

export function writeFileConfig(data: FileConfig): void {
  const paths = getPaths();
  writeTextFileEnsuringParent(paths.configFile, renderYaml(data), "config file");
  try {
    fs.rmSync(paths.cacheFile, { force: true });
  } catch {
    // cache invalidation is best-effort
  }
}

function runtimePreset(name: string, cfg: PresetConfig, builtin: boolean): RuntimePreset | null {
  if (!cfg.flags) return null;
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

export function loadRuntimeConfig(): RuntimeConfig {
  const file = readFileConfig();
  const presets = new Map<string, RuntimePreset>();
  const aliases = new Map<string, string>();

  for (const preset of builtInPresets) {
    presets.set(preset.name, { ...preset });
    if (preset.alias) aliases.set(preset.alias, preset.name);
  }

  for (const name of file.remove_builtins || []) {
    presets.delete(name);
    for (const [alias, target] of aliases.entries()) {
      if (target === name) aliases.delete(alias);
    }
  }

  for (const [name, cfg] of Object.entries(file.presets || {})) {
    const preset = runtimePreset(name, cfg, false);
    if (!preset) continue;
    presets.set(name, preset);
    if (preset.alias) aliases.set(preset.alias, name);
  }

  for (const [alias, target] of Array.from(aliases.entries())) {
    if (!presets.has(target)) aliases.delete(alias);
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

export function orderedPresets(config: RuntimeConfig): RuntimePreset[] {
  const used = new Set<string>();
  const result: RuntimePreset[] = [];
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

export function resolvePreset(config: RuntimeConfig, input: string): RuntimePreset | null {
  return config.presets.get(input) || config.presets.get(config.aliases.get(input) || "") || null;
}

export function presetByIndex(config: RuntimeConfig, index: number): RuntimePreset | null {
  return orderedPresets(config)[index - 1] || null;
}

export function writeCache(config: RuntimeConfig): void {
  const paths = getPaths();
  writeTextFileEnsuringParent(
    paths.cacheFile,
    JSON.stringify(
      {
        ux: config.ux,
        presets: Array.from(config.presets.values()),
        aliases: Object.fromEntries(config.aliases),
      },
      null,
      2,
    ),
    "cache file",
  );
}
