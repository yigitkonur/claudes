import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { configure } from "./configure";
import { FileConfig, RemapMode } from "./types";
import { loadRuntimeConfig, normalizeShellCommands, readFileConfig, writeCache, writeFileConfig } from "./config";
import { ask, colors, copyFile, ensureDir, getPaths, info, ok, packageRoot, step, warn } from "./utils";

function commandExists(name: string): boolean {
  const result = spawnSync("zsh", ["-lc", `command -v ${name} >/dev/null 2>&1`], { stdio: "ignore" });
  return result.status === 0;
}

function copyRuntime(): void {
  const root = packageRoot();
  const paths = getPaths();
  const distSrc = path.join(root, "dist");
  if (!fs.existsSync(distSrc)) {
    throw new Error(`Compiled runtime not found at ${distSrc}. Run: npm run build`);
  }

  ensureDir(paths.v2Dir, "v2 install directory");
  fs.rmSync(path.join(paths.v2Dir, "dist"), { recursive: true, force: true });
  fs.cpSync(distSrc, path.join(paths.v2Dir, "dist"), { recursive: true });
  for (const file of ["package.json", "README.md", "CHANGELOG.md", "LICENSE"]) {
    const src = path.join(root, file);
    if (fs.existsSync(src)) copyFile(src, path.join(paths.v2Dir, file));
  }
}

function zshCoreContent(): string {
  const paths = getPaths();
  return `# claudes v2 — https://github.com/yigitkonur/claudes
_claudes_node=${JSON.stringify(path.join(paths.v2Dir, "dist", "cli.js"))}
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

function zshUxContent(): string {
  const paths = getPaths();
  return `# claudes v2 UX layer — https://github.com/yigitkonur/claudes
_claudes_node=${JSON.stringify(path.join(paths.v2Dir, "dist", "cli.js"))}

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

function installShellFile(name: string, content: string, linkName: string): void {
  const paths = getPaths();
  const target = path.join(paths.v2Dir, name);
  fs.writeFileSync(target, content, "utf8");

  if (fs.existsSync(paths.zshrcDir) && fs.statSync(paths.zshrcDir).isDirectory()) {
    const link = path.join(paths.zshrcDir, linkName);
    fs.rmSync(link, { force: true });
    fs.symlinkSync(target, link);
    ok(`Linked to ${link}`);
    return;
  }

  const marker = `# ${name.replace(".zsh", "")} — https://github.com/yigitkonur/claudes`;
  const sourceLine = `[ -f "${target}" ] && source "${target}"`;
  const existing = fs.existsSync(paths.zshrc) ? fs.readFileSync(paths.zshrc, "utf8") : "";
  if (!existing.includes(marker)) {
    fs.appendFileSync(paths.zshrc, `\n${marker}\n${sourceLine}\n`, "utf8");
    ok(`Appended ${name} to ${paths.zshrc}`);
  } else {
    ok(`Already sourced from ${paths.zshrc}`);
  }
}

function dumpZshConfig(file: string, script: string): string {
  const result = spawnSync("zsh", ["-c", script, "claudes-migrate", file], {
    encoding: "utf8",
  });
  return result.status === 0 ? result.stdout : "";
}

function migrateLegacy(): FileConfig | null {
  const paths = getPaths();
  const oldPresets = path.join(paths.configDir, "presets.zsh");
  const oldUx = path.join(paths.configDir, "ux-settings.zsh");
  if (!fs.existsSync(oldPresets) && !fs.existsSync(oldUx)) return null;

  warn("Old config files found (.zsh format).");
  const data: FileConfig = { ux: {}, presets: {}, remove_builtins: [] };

  if (fs.existsSync(oldPresets)) {
    const out = dumpZshConfig(
      oldPresets,
      'source "$1"; for k in ${(ko)CLAUDES_PRESETS}; do printf "PRESET\\t%s\\t%s\\n" "$k" "${CLAUDES_PRESETS[$k]}"; done; for k in ${(ko)CLAUDES_DESCRIPTIONS}; do printf "DESC\\t%s\\t%s\\n" "$k" "${CLAUDES_DESCRIPTIONS[$k]}"; done; for k in ${(ko)CLAUDES_ALIASES}; do printf "ALIAS\\t%s\\t%s\\n" "$k" "${CLAUDES_ALIASES[$k]}"; done',
    );
    for (const line of out.split(/\r?\n/)) {
      const [kind, key, value] = line.split("\t");
      if (!kind || !key || value === undefined) continue;
      data.presets ||= {};
      if (kind === "PRESET") data.presets[key] = { ...(data.presets[key] || {}), flags: value };
      if (kind === "DESC") data.presets[key] = { ...(data.presets[key] || {}), description: value };
      if (kind === "ALIAS") data.presets[value] = { ...(data.presets[value] || {}), alias: key };
    }
  }

  if (fs.existsSync(oldUx)) {
    const out = dumpZshConfig(
      oldUx,
      'source "$1"; echo "ORDER:${CLAUDES_ORDER[*]:-}"; echo "DEFAULT:${CLAUDES_DEFAULT:-standard}"; echo "REMAP:${CLAUDES_REMAP_CLAUDE:-warp}"',
    );
    for (const line of out.split(/\r?\n/)) {
      if (line.startsWith("ORDER:")) {
        const order = line.slice(6).trim();
        if (order) data.ux!.order = order.split(/\s+/);
      }
      if (line.startsWith("DEFAULT:")) data.ux!.default = line.slice(8).trim() || "standard";
      if (line.startsWith("REMAP:")) {
        const remap = line.slice(6).trim();
        if (remap === "warp" || remap === "all" || remap === "none") data.ux!.remap = remap;
      }
    }
  }
  return data;
}

export function recommendedConfig(): FileConfig {
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

function mergeUx(
  data: FileConfig,
  order: string[],
  defaultPreset: string,
  remap: RemapMode,
  commands: string[],
): FileConfig {
  return {
    ...data,
    ux: {
      ...(data.ux || {}),
      ...(order.length ? { order } : {}),
      default: defaultPreset,
      remap,
      commands: normalizeShellCommands(commands),
    },
  };
}

function parseShellCommandSelection(value: string): string[] {
  const byNumber: Record<string, string> = {
    "1": "claude",
    "2": "claudes",
    "3": "ccp",
    "4": "claude-preset",
  };
  const normalized = value
    .split(/[\s,]+/)
    .map((part) => byNumber[part] || part.trim())
    .filter(Boolean);
  return normalizeShellCommands(normalized);
}

export async function install(): Promise<number> {
  const paths = getPaths();

  console.log("");
  console.log(`${colors.bold}  claudes${colors.reset} — Claude Code preset picker`);
  console.log(`${colors.dim}  https://github.com/yigitkonur/claudes${colors.reset}\n`);

  if (!commandExists("zsh")) throw new Error("zsh is required. Install zsh first.");

  step("Step 1/4 — Core install");
  ensureDir(paths.installDir, "install directory");
  ensureDir(paths.configDir, "config directory");
  copyRuntime();
  ok(`Scripts at ${paths.v2Dir}/`);

  const migrated = migrateLegacy();
  if (migrated && !fs.existsSync(paths.configFile)) {
    const doMigrate = await ask("Migrate to claudes.yaml? [Y/n]:");
    if (doMigrate.toLowerCase() !== "n") {
      writeFileConfig(migrated);
      ok(`Migrated to ${paths.configFile}`);
    }
  }

  step("Step 2/4 — Commands and UX");
  console.log("  Choose which shell commands should open the preset picker:\n");
  console.log(`    1) claude         ${colors.dim}overrides the raw claude command; presets still launch the real binary${colors.reset}`);
  console.log(`    2) claudes        ${colors.dim}current project command${colors.reset}`);
  console.log(`    3) ccp            ${colors.dim}short for Claude Code presets${colors.reset}`);
  console.log(`    4) claude-preset  ${colors.dim}singular compatibility alias${colors.reset}\n`);
  console.log(`  ${colors.dim}Enter numbers or names separated by spaces/commas.${colors.reset}`);
  const commandChoice = await ask("Commands [1 2 3 4]:");
  const selectedCommands = parseShellCommandSelection(commandChoice || "1 2 3 4");
  ok(`Shell commands: ${selectedCommands.join(", ")}`);

  installShellFile("claudes.zsh", zshCoreContent(), "90-claudes.zsh");

  console.log("");
  console.log("  The UX layer adds:");
  console.log(`    • ${colors.bold}Single-key picker${colors.reset}  — 1/2/3 or p/s/q, no Enter needed`);
  console.log(`    • ${colors.bold}Enter default${colors.reset}      — bare Enter picks your chosen default`);
  console.log(`    • ${colors.bold}claude1..claude9${colors.reset}  — jump to preset N from the CLI`);
  console.log(`    • ${colors.bold}selected aliases${colors.reset} — ${selectedCommands.join(", ")} open this picker\n`);

  const wantUx = await ask("Install enhanced UX? [Y/n]:");
  const installUx = wantUx.toLowerCase() !== "n";
  let uxOrder: string[] = [];
  let uxDefault = "standard";
  const uxRemap: RemapMode = selectedCommands.includes("claude") ? "all" : "none";

  if (installUx) {
    console.log(`\n  ${colors.bold}Default preset${colors.reset} — bare Enter selects:`);
    const defaultChoice = await ask("Default [standard]:");
    if (defaultChoice) uxDefault = defaultChoice;

    installShellFile("ux.zsh", zshUxContent(), "91-claudes-ux.zsh");
  }

  step("Step 3/4 — Presets");
  if (fs.existsSync(paths.configFile)) {
    ok(`Using existing ${paths.configFile}`);
  } else {
    console.log("  Choose a preset scheme:\n");
    console.log(`    ${colors.bold}1) Recommended${colors.reset}  4-slot scheme:`);
    console.log(`       ${colors.dim}  plan     · Opus max + plan mode${colors.reset}`);
    console.log(`       ${colors.dim}  max      · Opus max + skip permissions (yolo)${colors.reset}`);
    console.log(`       ${colors.dim}  standard · Sonnet auto + skip permissions (daily)${colors.reset}`);
    console.log(`       ${colors.dim}  quick    · Sonnet low + skip permissions (fast)${colors.reset}\n`);
    console.log(`    ${colors.bold}2) Built-in defaults${colors.reset}  standard / quick / plan / research`);
    console.log(`    ${colors.bold}3) Custom${colors.reset}             configure interactively now`);
    console.log(`    ${colors.bold}4) Skip${colors.reset}               configure later via \`${selectedCommands[0]} config\`\n`);

    const presetChoice = await ask("Choice [1]:");
    if (presetChoice === "" || presetChoice === "1") {
      const config = recommendedConfig();
      uxOrder = ["plan", "max", "standard", "quick"];
      writeFileConfig(config);
      ok(`Wrote recommended presets to ${paths.configFile}`);
    } else if (presetChoice === "2") {
      info("Keeping built-in defaults.");
    } else if (presetChoice === "3") {
      info("Launching interactive preset configurator...");
      await configure(["presets"]);
    } else if (presetChoice === "4") {
      info(`Skipped. Edit ${paths.configFile} or run: ${selectedCommands[0]} config`);
    } else {
      warn("Unknown choice — keeping built-in defaults.");
    }
  }

  step("Step 4/4 — Finishing up");
  if (installUx) {
    const fileConfig = fs.existsSync(paths.configFile) ? readFileConfig() : {};
    writeFileConfig(mergeUx(fileConfig, uxOrder, uxDefault, uxRemap, selectedCommands));
    ok(`UX settings merged into ${paths.configFile}`);
  } else {
    const fileConfig = fs.existsSync(paths.configFile) ? readFileConfig() : {};
    writeFileConfig(mergeUx(fileConfig, [], uxDefault, uxRemap, selectedCommands));
    ok(`Shell command settings merged into ${paths.configFile}`);
  }

  if (fs.existsSync(paths.configFile)) {
    writeCache(loadRuntimeConfig());
    ok(`Cache warmed: ${paths.cacheFile}`);
  }

  console.log(`\n${colors.green}${colors.bold}  Done!${colors.reset}\n`);
  console.log(`  Restart shell or:  ${colors.dim}exec zsh${colors.reset}`);
  console.log(`  Open picker:       ${colors.dim}${selectedCommands.join(" / ")}${colors.reset}`);
  console.log(`  List presets:      ${colors.dim}${selectedCommands[0]} list${colors.reset}`);
  console.log(`  Manage presets:    ${colors.dim}${selectedCommands[0]} config${colors.reset}`);
  console.log(`  Config file:       ${colors.dim}${paths.configFile}${colors.reset}\n`);
  return 0;
}
