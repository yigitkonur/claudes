#!/usr/bin/env node
import { configure } from "./configure";
import { install } from "./install";
import { printHelp, printPresets, positionName, remapMode, runCliPreset, runPreset, showPreset } from "./runner";
import { loadRuntimeConfig, presetByIndex } from "./config";
import { runSelfTests } from "./selftest";
import { err } from "./utils";

async function main(): Promise<number> {
  const args = process.argv.slice(2);
  const [command, ...rest] = args;

  if (command === "help" || command === "-h" || command === "--help") {
    printHelp();
    return 0;
  }
  if (command === "list" || command === "ls") {
    printPresets();
    return 0;
  }
  if (command === "show") {
    if (!rest[0]) {
      err("usage: claudes show <preset>");
      return 1;
    }
    return showPreset(rest[0]);
  }
  if (command === "install") return await install();
  if (command === "config") return await configure(rest);
  if (command === "test") return runSelfTests();

  if (command === "__pos") {
    const index = Number(rest[0]);
    if (!Number.isInteger(index) || index < 1) {
      err("usage: claudes __pos <index> [args...]");
      return 1;
    }
    const config = loadRuntimeConfig();
    const preset = presetByIndex(config, index);
    if (!preset) {
      err(`no preset at position ${index}`);
      return 1;
    }
    return await runPreset(preset, rest.slice(1));
  }
  if (command === "__remap") {
    console.log(remapMode());
    return 0;
  }
  if (command === "__pos-name") {
    const name = positionName(Number(rest[0]));
    if (name) console.log(name);
    return name ? 0 : 1;
  }

  return await runCliPreset(args);
}

main()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((error) => {
    err(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
