import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  parseYaml,
  renderYaml,
  builtInPresets,
  loadRuntimeConfig,
  orderedPresets,
  writeCache,
  writeFileConfig,
} from "./config";
import { recommendedConfig } from "./install";
import { formatResult } from "./runner";
import { splitShellWords } from "./utils";

type Test = { name: string; fn: () => void };

function assert(condition: unknown, message: string): void {
  if (!condition) throw new Error(message);
}

function withTempHome(fn: (dir: string) => void): void {
  const oldHome = process.env.HOME;
  const oldXdg = process.env.XDG_CONFIG_HOME;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "claudes-ts-test-"));
  process.env.HOME = dir;
  process.env.XDG_CONFIG_HOME = path.join(dir, ".config");
  try {
    fn(dir);
  } finally {
    if (oldHome === undefined) delete process.env.HOME;
    else process.env.HOME = oldHome;
    if (oldXdg === undefined) delete process.env.XDG_CONFIG_HOME;
    else process.env.XDG_CONFIG_HOME = oldXdg;
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

const tests: Test[] = [
  {
    name: "YAML parse handles ux, presets, env, remove_builtins",
    fn: () => {
      const data = parseYaml(`ux:
  order: [plan, max, standard, quick]
  default: standard
  remap: all
  commands: [claude, claudes, ccp, claude-preset]

presets:
  review:
    flags: "--model sonnet --effort low"
    description: "read-only"
    alias: rv
    env:
      CLAUDE_CODE_MAX_OUTPUT_TOKENS: "16000"

remove_builtins:
  - research
`);
      assert(data.ux?.order?.[0] === "plan", "ux order missing");
      assert(data.ux?.remap === "all", "remap missing");
      assert(data.ux?.commands?.includes("ccp"), "commands missing");
      assert(data.presets?.review?.env?.CLAUDE_CODE_MAX_OUTPUT_TOKENS === "16000", "env missing");
      assert(data.remove_builtins?.[0] === "research", "remove_builtins missing");
    },
  },
  {
    name: "YAML render round trips recommended config",
    fn: () => {
      const rendered = renderYaml(recommendedConfig());
      const parsed = parseYaml(rendered);
      assert(parsed.presets?.max?.alias === "m", "max alias missing");
      assert(parsed.remove_builtins?.includes("research"), "research removal missing");
    },
  },
  {
    name: "Built-ins preserve four preset contract",
    fn: () => {
      assert(builtInPresets.length === 4, "expected four built-ins");
      assert(builtInPresets.every((preset) => preset.flags), "built-ins need flags");
    },
  },
  {
    name: "Runtime config applies recommended order and removals",
    fn: () => {
      withTempHome(() => {
        const configDir = path.join(process.env.XDG_CONFIG_HOME!, "claudes");
        fs.mkdirSync(configDir, { recursive: true });
        fs.writeFileSync(path.join(configDir, "claudes.yaml"), renderYaml(recommendedConfig()));
        const runtime = loadRuntimeConfig();
        assert(!runtime.presets.has("research"), "research should be removed");
        assert(orderedPresets(runtime)[0]?.name === "plan", "plan should be first");
        assert(runtime.ux.commands[0] === "claudes", "default command should be claudes");
      });
    },
  },
  {
    name: "Config and cache writers recreate missing config directory",
    fn: () => {
      withTempHome(() => {
        const configDir = path.join(process.env.XDG_CONFIG_HOME!, "claudes");
        const configFile = path.join(configDir, "claudes.yaml");
        const cacheFile = path.join(configDir, ".claudes-cache.json");

        writeFileConfig(recommendedConfig());
        assert(fs.existsSync(configFile), "config file should be written");

        fs.rmSync(configDir, { recursive: true, force: true });
        writeCache(loadRuntimeConfig());
        assert(fs.existsSync(cacheFile), "cache file should be written");
      });
    },
  },
  {
    name: "Config writer retries if directory disappears during write",
    fn: () => {
      withTempHome(() => {
        const configDir = path.join(process.env.XDG_CONFIG_HOME!, "claudes");
        const configFile = path.join(configDir, "claudes.yaml");
        const originalWriteFileSync = fs.writeFileSync;
        let failedOnce = false;

        fs.writeFileSync = ((file, data, options) => {
          if (!failedOnce && file === configFile) {
            failedOnce = true;
            fs.rmSync(configDir, { recursive: true, force: true });
            const error = new Error("simulated missing config directory") as NodeJS.ErrnoException;
            error.code = "ENOENT";
            throw error;
          }
          return (
            originalWriteFileSync as unknown as (
              target: fs.PathOrFileDescriptor,
              contents: string | NodeJS.ArrayBufferView,
              writeOptions?: fs.WriteFileOptions,
            ) => void
          )(file, data, options);
        }) as typeof fs.writeFileSync;

        try {
          writeFileConfig(recommendedConfig());
        } finally {
          fs.writeFileSync = originalWriteFileSync;
        }

        assert(failedOnce, "test should simulate one ENOENT");
        assert(fs.existsSync(configFile), "config file should be written after retry");
      });
    },
  },
  {
    name: "Shell flag splitter handles quoted values",
    fn: () => {
      const words = splitShellWords('--model sonnet --append-system-prompt "read only"');
      assert(words[2] === "--append-system-prompt", "flag order wrong");
      assert(words[3] === "read only", "quoted value not preserved");
    },
  },
];

export function runSelfTests(): number {
  let pass = 0;
  let fail = 0;
  for (const test of tests) {
    try {
      test.fn();
      pass += 1;
      console.log(formatResult(test.name, true));
    } catch (error) {
      fail += 1;
      console.log(formatResult(`${test.name}: ${error instanceof Error ? error.message : String(error)}`, false));
    }
  }
  console.log(`\n  passed: ${pass}   failed: ${fail}\n`);
  return fail === 0 ? 0 : 1;
}
