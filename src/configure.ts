import { allowedShellCommands, builtInPresets, normalizeShellCommands, readFileConfig, writeFileConfig } from "./config";
import { FileConfig, PresetConfig, RemapMode } from "./types";
import { ask, colors, getPaths, ok, warn } from "./utils";

function presetNames(data: FileConfig): string[] {
  return Object.keys(data.presets || {});
}

function upsertPreset(data: FileConfig, name: string, preset: PresetConfig): FileConfig {
  return {
    ...data,
    presets: {
      ...(data.presets || {}),
      [name]: preset,
    },
  };
}

function removePreset(data: FileConfig, name: string): FileConfig {
  const presets = { ...(data.presets || {}) };
  delete presets[name];
  return { ...data, presets };
}

function autoDesc(flags: string): string {
  const model = flags.includes("opus") ? "Opus 4.7" : "Sonnet 4.6";
  const effortMatch = flags.match(/--effort\s+(\S+)/);
  const effort = effortMatch ? `${effortMatch[1]} effort` : "auto effort";
  let mode = "default mode";
  if (flags.includes("dangerously-skip")) mode = "skip permissions";
  else if (flags.includes("--permission-mode plan")) mode = "plan mode";
  else if (flags.includes("acceptEdits")) mode = "accept edits";
  return `${model} · ${effort} · ${mode}`;
}

async function buildFlags(): Promise<string> {
  console.log(`\n${colors.bold}Model${colors.reset}\n`);
  console.log("    1) sonnet  — Sonnet 4.6 (fast, daily driver)");
  console.log("    2) opus    — Opus 4.7 (smartest, slower)\n");
  const modelChoice = await ask("Choice [1]:");
  const model = modelChoice === "2" ? "opus" : "sonnet";

  console.log(`\n${colors.bold}Effort / reasoning${colors.reset}\n`);
  console.log("    1) auto   — Claude decides");
  console.log("    2) low    — fast, minimal reasoning");
  console.log("    3) medium");
  console.log("    4) high");
  console.log("    5) max    — slowest, deepest reasoning\n");
  const effortChoice = await ask("Choice [1]:");
  const effort =
    effortChoice === "2"
      ? "--effort low"
      : effortChoice === "3"
        ? "--effort medium"
        : effortChoice === "4"
          ? "--effort high"
          : effortChoice === "5"
            ? "--effort max"
            : "";

  console.log(`\n${colors.bold}Permission mode${colors.reset}\n`);
  console.log("    1) default          — normal approvals");
  console.log("    2) skip (yolo)      — --dangerously-skip-permissions");
  console.log("    3) plan             — plan-only, no execution");
  console.log("    4) acceptEdits      — auto-accept file edits, approve shell\n");
  const modeChoice = await ask("Choice [1]:");
  const mode =
    modeChoice === "2"
      ? "--dangerously-skip-permissions"
      : modeChoice === "3"
        ? "--permission-mode plan"
        : modeChoice === "4"
          ? "--permission-mode acceptEdits"
          : "--permission-mode default";

  return [`--model ${model}`, effort, mode].filter(Boolean).join(" ");
}

function showUserPresets(data: FileConfig): void {
  const names = presetNames(data);
  if (!names.length) {
    console.log(`    ${colors.dim}(no user presets — built-ins are active)${colors.reset}`);
    return;
  }
  names.forEach((name, index) => {
    const preset = data.presets?.[name] || {};
    const label = `${name}${preset.alias ? ` (${preset.alias})` : ""}`;
    console.log(`    ${index + 1}) ${label.padEnd(22)} ${colors.dim}${preset.flags || ""}${colors.reset}`);
    if (preset.description) console.log(`       ${"".padEnd(22)} ${colors.dim}${preset.description}${colors.reset}`);
  });
}

async function addPreset(): Promise<void> {
  let data = readFileConfig();
  console.log(`\n${colors.bold}Add preset${colors.reset}\n`);
  const name = await ask("Preset name (e.g. 'myfast'):");
  if (!name) {
    warn("Cancelled.");
    return;
  }
  if (data.presets?.[name]) {
    warn(`Preset '${name}' already exists. Use Edit to modify it.`);
    return;
  }
  const flags = await buildFlags();
  const generated = autoDesc(flags);
  console.log(`\n  Auto-description: ${colors.dim}${generated}${colors.reset}`);
  const desc = (await ask("Custom description [enter to keep]:")) || generated;
  let alias = await ask("Single-char alias [enter to skip]:");
  if (alias.length > 1) alias = alias.slice(0, 1);
  const prompt = await ask("System-prompt addendum [enter to skip]:");
  const mcp = await ask("MCP config path [enter to skip]:");

  console.log("\n  Preview:");
  console.log(`    name:  ${name}`);
  console.log(`    flags: ${flags}`);
  console.log(`    desc:  ${desc}`);
  if (alias) console.log(`    alias: ${alias}`);
  if (prompt) console.log(`    prompt: ${prompt}`);
  if (mcp) console.log(`    mcp:   ${mcp}`);
  console.log("");
  const confirm = await ask("Save? [Y/n]:");
  if (confirm.toLowerCase() === "n") {
    warn("Cancelled.");
    return;
  }

  data = upsertPreset(data, name, {
    flags,
    description: desc,
    ...(alias ? { alias } : {}),
    ...(prompt ? { prompt } : {}),
    ...(mcp ? { mcp } : {}),
  });
  writeFileConfig(data);
  ok(`Preset '${name}' added.`);
}

async function editPreset(): Promise<void> {
  let data = readFileConfig();
  const names = presetNames(data);
  if (!names.length) {
    warn("No user presets to edit.");
    return;
  }
  console.log(`\n${colors.bold}Edit preset${colors.reset}\n`);
  names.forEach((name, index) => console.log(`    ${index + 1}) ${name}`));
  console.log("");
  const index = Number(await ask("Preset number:"));
  if (!Number.isInteger(index) || index < 1 || index > names.length) {
    warn("Invalid number.");
    return;
  }
  const name = names[index - 1];
  const preset = { ...(data.presets?.[name] || {}) };
  console.log(`\n  Editing '${name}'`);
  const rebuild = await ask("Rebuild flags interactively? [Y/n]:");
  if (rebuild.toLowerCase() !== "n") {
    preset.flags = await buildFlags();
  } else {
    console.log(`  Current flags: ${colors.dim}${preset.flags || ""}${colors.reset}`);
    const flags = await ask("New flags [enter to keep]:");
    if (flags) preset.flags = flags;
  }

  console.log(`  Current description: ${colors.dim}${preset.description || ""}${colors.reset}`);
  const desc = await ask("New description [enter to keep]:");
  if (desc) preset.description = desc;

  console.log(`  Current alias: ${colors.dim}${preset.alias || "(none)"}${colors.reset}`);
  const alias = await ask("New alias [enter to keep, - to clear]:");
  if (alias === "-") delete preset.alias;
  else if (alias) preset.alias = alias.slice(0, 1);

  console.log(`  Current prompt: ${colors.dim}${preset.prompt || "(none)"}${colors.reset}`);
  const prompt = await ask("New prompt [enter to keep, - to clear]:");
  if (prompt === "-") delete preset.prompt;
  else if (prompt) preset.prompt = prompt;

  console.log(`  Current mcp: ${colors.dim}${preset.mcp || "(none)"}${colors.reset}`);
  const mcp = await ask("New mcp path [enter to keep, - to clear]:");
  if (mcp === "-") delete preset.mcp;
  else if (mcp) preset.mcp = mcp;

  data = upsertPreset(data, name, preset);
  writeFileConfig(data);
  ok(`Preset '${name}' updated.`);
}

async function deletePreset(): Promise<void> {
  let data = readFileConfig();
  const names = presetNames(data);
  if (!names.length) {
    warn("No user presets to remove.");
    return;
  }
  console.log(`\n${colors.bold}Remove preset${colors.reset}\n`);
  names.forEach((name, index) => console.log(`    ${index + 1}) ${name}`));
  console.log("");
  const index = Number(await ask("Preset number to remove:"));
  if (!Number.isInteger(index) || index < 1 || index > names.length) {
    warn("Invalid number.");
    return;
  }
  const name = names[index - 1];
  const confirm = await ask(`Remove '${name}'? [y/N]:`);
  if (confirm.toLowerCase() !== "y") {
    warn("Cancelled.");
    return;
  }
  data = removePreset(data, name);
  writeFileConfig(data);
  ok(`Preset '${name}' removed.`);
}

async function managePresets(): Promise<void> {
  while (true) {
    const data = readFileConfig();
    const paths = getPaths();
    console.log(`\n${colors.bold}Preset manager${colors.reset}\n`);
    console.log(`  ${colors.dim}User presets in ${paths.configFile}:${colors.reset}\n`);
    showUserPresets(data);
    console.log("\n    a) Add preset");
    console.log("    e) Edit preset");
    console.log("    r) Remove preset");
    console.log("    q) Back / quit\n");
    const action = (await ask("Choice:")).toLowerCase();
    if (action === "a") await addPreset();
    else if (action === "e") await editPreset();
    else if (action === "r") await deletePreset();
    else if (action === "q" || action === "") return;
    else warn("Unknown choice.");
  }
}

async function manageUx(): Promise<void> {
  const data = readFileConfig();
  const currentOrder = data.ux?.order?.join(" ") || "";
  const currentCommands = normalizeShellCommands(data.ux?.commands).join(" ");
  let defaultPreset = data.ux?.default || "standard";

  console.log(`\n${colors.bold}UX settings${colors.reset}\n`);
  console.log("  Current:");
  console.log(`    Order:   ${colors.dim}${currentOrder || "(alphabetical)"}${colors.reset}`);
  console.log(`    Default: ${colors.dim}${defaultPreset}${colors.reset}`);
  console.log(`    Commands:${colors.dim} ${currentCommands}${colors.reset}\n`);
  console.log(`${colors.bold}Picker order${colors.reset} — space-separated preset names`);
  console.log(`${colors.dim}Example: plan max standard quick${colors.reset}`);
  const order = (await ask(`Order [${currentOrder}]:`)) || currentOrder;
  const newDefault = await ask(`Default [${defaultPreset}]:`);
  if (newDefault) defaultPreset = newDefault;
  console.log(`\n${colors.bold}Shell commands${colors.reset} — choose any of: ${allowedShellCommands.join(", ")}`);
  const commandInput = await ask(`Commands [${currentCommands}]:`);
  const commands = normalizeShellCommands(commandInput ? commandInput.split(/[\s,]+/) : data.ux?.commands);
  const remap: RemapMode = commands.includes("claude") ? "all" : "none";

  writeFileConfig({
    ...data,
    ux: {
      order: order.split(/\s+/).filter(Boolean),
      default: defaultPreset,
      remap,
      commands,
    },
  });
  ok("Updated UX settings.");
}

export async function configure(args: string[]): Promise<number> {
  const target = args[0] || "";
  if (target === "presets") {
    await managePresets();
    return 0;
  }
  if (target === "ux") {
    await manageUx();
    return 0;
  }

  const paths = getPaths();
  console.log(`\n${colors.bold}claudes config${colors.reset}\n`);
  console.log(`  Config: ${colors.dim}${paths.configFile}${colors.reset}\n`);
  console.log("    1) Manage presets");
  console.log("    2) UX settings (order, default, shell commands)");
  console.log("    q) Quit\n");
  const choice = (await ask("Choice:")).toLowerCase();
  if (choice === "1" || choice === "presets") await managePresets();
  else if (choice === "2" || choice === "ux") await manageUx();
  else if (choice !== "q" && choice !== "") warn("Unknown choice.");
  return 0;
}

export function builtInNames(): string[] {
  return builtInPresets.map((preset) => preset.name);
}
