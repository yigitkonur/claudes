"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.runSelfTests = runSelfTests;
const node_fs_1 = __importDefault(require("node:fs"));
const node_os_1 = __importDefault(require("node:os"));
const node_path_1 = __importDefault(require("node:path"));
const config_1 = require("./config");
const install_1 = require("./install");
const runner_1 = require("./runner");
const utils_1 = require("./utils");
function assert(condition, message) {
    if (!condition)
        throw new Error(message);
}
function withTempHome(fn) {
    const oldHome = process.env.HOME;
    const oldXdg = process.env.XDG_CONFIG_HOME;
    const dir = node_fs_1.default.mkdtempSync(node_path_1.default.join(node_os_1.default.tmpdir(), "claudes-ts-test-"));
    process.env.HOME = dir;
    process.env.XDG_CONFIG_HOME = node_path_1.default.join(dir, ".config");
    try {
        fn(dir);
    }
    finally {
        if (oldHome === undefined)
            delete process.env.HOME;
        else
            process.env.HOME = oldHome;
        if (oldXdg === undefined)
            delete process.env.XDG_CONFIG_HOME;
        else
            process.env.XDG_CONFIG_HOME = oldXdg;
        node_fs_1.default.rmSync(dir, { recursive: true, force: true });
    }
}
const tests = [
    {
        name: "YAML parse handles ux, presets, env, remove_builtins",
        fn: () => {
            const data = (0, config_1.parseYaml)(`ux:
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
            const rendered = (0, config_1.renderYaml)((0, install_1.recommendedConfig)());
            const parsed = (0, config_1.parseYaml)(rendered);
            assert(parsed.presets?.max?.alias === "m", "max alias missing");
            assert(parsed.remove_builtins?.includes("research"), "research removal missing");
        },
    },
    {
        name: "Built-ins preserve four preset contract",
        fn: () => {
            assert(config_1.builtInPresets.length === 4, "expected four built-ins");
            assert(config_1.builtInPresets.every((preset) => preset.flags), "built-ins need flags");
        },
    },
    {
        name: "Runtime config applies recommended order and removals",
        fn: () => {
            withTempHome(() => {
                const configDir = node_path_1.default.join(process.env.XDG_CONFIG_HOME, "claudes");
                node_fs_1.default.mkdirSync(configDir, { recursive: true });
                node_fs_1.default.writeFileSync(node_path_1.default.join(configDir, "claudes.yaml"), (0, config_1.renderYaml)((0, install_1.recommendedConfig)()));
                const runtime = (0, config_1.loadRuntimeConfig)();
                assert(!runtime.presets.has("research"), "research should be removed");
                assert((0, config_1.orderedPresets)(runtime)[0]?.name === "plan", "plan should be first");
                assert(runtime.ux.commands[0] === "claudes", "default command should be claudes");
            });
        },
    },
    {
        name: "Shell flag splitter handles quoted values",
        fn: () => {
            const words = (0, utils_1.splitShellWords)('--model sonnet --append-system-prompt "read only"');
            assert(words[2] === "--append-system-prompt", "flag order wrong");
            assert(words[3] === "read only", "quoted value not preserved");
        },
    },
];
function runSelfTests() {
    let pass = 0;
    let fail = 0;
    for (const test of tests) {
        try {
            test.fn();
            pass += 1;
            console.log((0, runner_1.formatResult)(test.name, true));
        }
        catch (error) {
            fail += 1;
            console.log((0, runner_1.formatResult)(`${test.name}: ${error instanceof Error ? error.message : String(error)}`, false));
        }
    }
    console.log(`\n  passed: ${pass}   failed: ${fail}\n`);
    return fail === 0 ? 0 : 1;
}
