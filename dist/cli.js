#!/usr/bin/env node
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const configure_1 = require("./configure");
const install_1 = require("./install");
const runner_1 = require("./runner");
const config_1 = require("./config");
const selftest_1 = require("./selftest");
const utils_1 = require("./utils");
async function main() {
    const args = process.argv.slice(2);
    const [command, ...rest] = args;
    if (command === "help" || command === "-h" || command === "--help") {
        (0, runner_1.printHelp)();
        return 0;
    }
    if (command === "list" || command === "ls") {
        (0, runner_1.printPresets)();
        return 0;
    }
    if (command === "show") {
        if (!rest[0]) {
            (0, utils_1.err)("usage: claudes show <preset>");
            return 1;
        }
        return (0, runner_1.showPreset)(rest[0]);
    }
    if (command === "install")
        return await (0, install_1.install)();
    if (command === "config")
        return await (0, configure_1.configure)(rest);
    if (command === "test")
        return (0, selftest_1.runSelfTests)();
    if (command === "__pos") {
        const index = Number(rest[0]);
        if (!Number.isInteger(index) || index < 1) {
            (0, utils_1.err)("usage: claudes __pos <index> [args...]");
            return 1;
        }
        const config = (0, config_1.loadRuntimeConfig)();
        const preset = (0, config_1.presetByIndex)(config, index);
        if (!preset) {
            (0, utils_1.err)(`no preset at position ${index}`);
            return 1;
        }
        return await (0, runner_1.runPreset)(preset, rest.slice(1));
    }
    if (command === "__remap") {
        console.log((0, runner_1.remapMode)());
        return 0;
    }
    if (command === "__commands") {
        console.log((0, runner_1.shellCommands)().join(" "));
        return 0;
    }
    if (command === "__pos-name") {
        const name = (0, runner_1.positionName)(Number(rest[0]));
        if (name)
            console.log(name);
        return name ? 0 : 1;
    }
    return await (0, runner_1.runCliPreset)(args);
}
main()
    .then((code) => {
    process.exitCode = code;
})
    .catch((error) => {
    (0, utils_1.err)(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
});
