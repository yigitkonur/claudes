import fs from "node:fs";
import { spawn } from "node:child_process";
import { RuntimeConfig, RuntimePreset } from "./types";
import { loadRuntimeConfig, orderedPresets, presetByIndex, resolvePreset } from "./config";
import { colors, err, expandHome, findExecutable, readSingleKey, splitShellWords } from "./utils";

function markers(preset: RuntimePreset): string {
  const marks: string[] = [];
  if (preset.flags.startsWith("fn:")) marks.push("fn");
  if (preset.env && Object.keys(preset.env).length) marks.push("+env");
  if (preset.mcp) marks.push("+mcp");
  if (preset.prompt) marks.push("+prompt");
  return marks.length ? ` [${marks.join(" ")}]` : "";
}

function reverseAlias(config: RuntimeConfig): Map<string, string> {
  const result = new Map<string, string>();
  for (const [alias, target] of config.aliases.entries()) {
    if (!result.has(target)) result.set(target, alias);
  }
  return result;
}

export function printPresets(config = loadRuntimeConfig()): void {
  const aliases = reverseAlias(config);
  console.log("");
  for (const [index, preset] of orderedPresets(config).entries()) {
    const alias = aliases.get(preset.name);
    const label = `${preset.name}${alias ? ` (${alias})` : ""}`;
    console.log(
      `    ${index + 1}) ${label.padEnd(18)} · ${preset.description}${markers(preset)}`,
    );
  }
  console.log("");
}

export function printHelp(): void {
  console.log(`claude-presets / claudes — Claude Code preset picker

USAGE
  claude-presets install        Install shell integration
  claudes                       Interactive picker
  claudes <preset> [args...]    Run a specific preset
  claudes list                  List all presets
  claudes show <preset>         Show resolved config for a preset
  claudes config [presets|ux]   Interactive preset & UX manager
  claudes test                  Run self tests
  claudes help                  Show this help

EXAMPLES
  npx claude-presets install
  claudes
  ccp list
  claude-preset show standard
  claudes standard
  claudes s "fix the bug"
  claudes plan --resume
  claudes --resume
`);
}

export function showPreset(name: string, config = loadRuntimeConfig()): number {
  const preset = resolvePreset(config, name);
  if (!preset) {
    err(`unknown preset: ${name}`);
    return 1;
  }
  console.log(`preset:       ${preset.name}`);
  console.log(`description:  ${preset.description}`);
  console.log(`flags:        ${preset.flags}`);
  if (preset.env && Object.keys(preset.env).length) {
    console.log(`env:          ${Object.entries(preset.env).map(([k, v]) => `${k}=${v}`).join(" ")}`);
  }
  if (preset.mcp) console.log(`mcp-config:   ${preset.mcp}`);
  if (preset.prompt) console.log(`prompt:       ${preset.prompt}`);
  return 0;
}

async function choosePreset(config: RuntimeConfig): Promise<RuntimePreset | null> {
  if (!process.stdin.isTTY) {
    err("no preset and stdin is not a TTY — pass a preset name");
    return null;
  }
  console.log("");
  console.log("  Choose Claude preset:");
  printPresets(config);
  process.stdout.write(`  > [enter = ${config.ux.default}] `);
  const key = await readSingleKey();
  console.log("");

  if (key === "\r" || key === "\n") return resolvePreset(config, config.ux.default);
  const normalized = key.toLowerCase();
  if (/^[0-9]$/.test(normalized)) return presetByIndex(config, Number(normalized));
  return resolvePreset(config, normalized);
}

function spawnAndExit(command: string, args: string[], env?: NodeJS.ProcessEnv): Promise<number> {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      stdio: "inherit",
      env: env || process.env,
    });
    child.on("exit", (code, signal) => {
      if (signal) resolve(128);
      else resolve(code ?? 0);
    });
    child.on("error", (error) => {
      err(error.message);
      resolve(1);
    });
  });
}

async function runFnPreset(preset: RuntimePreset, rest: string[]): Promise<number> {
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

export async function runPreset(preset: RuntimePreset, rest: string[]): Promise<number> {
  if (preset.flags.startsWith("fn:")) return await runFnPreset(preset, rest);

  const claudeBin = findExecutable("claude");
  if (!claudeBin) {
    err("claude binary not found in PATH");
    return 127;
  }

  let args: string[];
  try {
    args = splitShellWords(preset.flags);
  } catch (error) {
    err(String(error instanceof Error ? error.message : error));
    return 1;
  }

  if (preset.mcp) {
    const mcpPath = expandHome(preset.mcp);
    if (!fs.existsSync(mcpPath)) {
      err(`MCP config not found for '${preset.name}': ${mcpPath}`);
      return 1;
    }
    args.push("--mcp-config", mcpPath);
  }
  if (preset.prompt) args.push("--append-system-prompt", preset.prompt);
  args.push(...rest);

  const env = { ...process.env, ...preset.env };
  console.log(`▶ ${preset.name} · ${preset.description}`);
  return await spawnAndExit(claudeBin, args, env);
}

export async function runCliPreset(args: string[]): Promise<number> {
  const config = loadRuntimeConfig();
  if (!args.length) {
    const preset = await choosePreset(config);
    if (!preset) return 1;
    return await runPreset(preset, []);
  }

  const [first, ...rest] = args;
  const claudeBin = findExecutable("claude");
  if (first.startsWith("-")) {
    if (!claudeBin) {
      err("claude binary not found in PATH");
      return 127;
    }
    return await spawnAndExit(claudeBin, [first, ...rest]);
  }

  const preset = resolvePreset(config, first);
  if (!preset) {
    err(`unknown preset '${first}' (run 'claudes list' or 'claudes help')`);
    return 1;
  }
  return await runPreset(preset, rest);
}

export function positionName(index: number): string | null {
  return presetByIndex(loadRuntimeConfig(), index)?.name || null;
}

export function remapMode(): string {
  return loadRuntimeConfig().ux.remap;
}

export function shellCommands(): string[] {
  return loadRuntimeConfig().ux.commands;
}

export function formatResult(label: string, pass: boolean): string {
  return `${pass ? colors.green : colors.red}${pass ? "[pass]" : "[FAIL]"}${colors.reset} ${label}`;
}
