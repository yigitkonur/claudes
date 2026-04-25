import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import readline from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";
import { CliPaths } from "./types";

export const colors = process.stdout.isTTY
  ? {
      bold: "\x1b[1m",
      dim: "\x1b[2m",
      reset: "\x1b[0m",
      green: "\x1b[0;32m",
      yellow: "\x1b[1;33m",
      blue: "\x1b[0;34m",
      red: "\x1b[0;31m",
    }
  : { bold: "", dim: "", reset: "", green: "", yellow: "", blue: "", red: "" };

export function ok(message: string): void {
  console.log(`${colors.green}[ok]${colors.reset} ${message}`);
}

export function info(message: string): void {
  console.log(`${colors.blue}[..]${colors.reset} ${message}`);
}

export function warn(message: string): void {
  console.log(`${colors.yellow}[!!]${colors.reset} ${message}`);
}

export function err(message: string): void {
  console.error(`${colors.red}[err]${colors.reset} ${message}`);
}

export function step(message: string): void {
  console.log(`\n${colors.bold}${message}${colors.reset}\n`);
}

export function getPaths(): CliPaths {
  const home = os.homedir();
  const configBase = process.env.XDG_CONFIG_HOME || path.join(home, ".config");
  const configDir = path.join(configBase, "claudes");
  const installDir = path.join(home, ".local", "share", "claudes");
  const v2Dir = path.join(installDir, "v2");
  return {
    home,
    configDir,
    configFile: path.join(configDir, "claudes.yaml"),
    cacheFile: path.join(configDir, ".claudes-cache.json"),
    installDir,
    v2Dir,
    zshrc: path.join(home, ".zshrc"),
    zshrcDir: path.join(home, ".zshrc.d"),
  };
}

export function ensureDir(dir: string, label: string): void {
  try {
    fs.mkdirSync(dir, { recursive: true });
  } catch (error) {
    throw new Error(`Failed to create ${label}: ${dir}\n${String(error)}`);
  }
  const stat = fs.statSync(dir);
  if (!stat.isDirectory()) throw new Error(`${label} is not a directory: ${dir}`);
  fs.accessSync(dir, fs.constants.W_OK);
}

export function expandHome(value: string): string {
  if (value === "~") return os.homedir();
  if (value.startsWith("~/")) return path.join(os.homedir(), value.slice(2));
  return value;
}

export function packageRoot(): string {
  return path.resolve(__dirname, "..");
}

export function shellQuote(value: string): string {
  return `'${value.replace(/'/g, `'\\''`)}'`;
}

export function splitShellWords(inputText: string): string[] {
  const words: string[] = [];
  let current = "";
  let quote: "'" | '"' | null = null;
  let escaping = false;

  for (const char of inputText) {
    if (escaping) {
      current += char;
      escaping = false;
      continue;
    }
    if (char === "\\" && quote !== "'") {
      escaping = true;
      continue;
    }
    if ((char === "'" || char === '"') && quote === null) {
      quote = char;
      continue;
    }
    if (char === quote) {
      quote = null;
      continue;
    }
    if (/\s/.test(char) && quote === null) {
      if (current) {
        words.push(current);
        current = "";
      }
      continue;
    }
    current += char;
  }

  if (escaping) current += "\\";
  if (quote) throw new Error("Unterminated quote in flags");
  if (current) words.push(current);
  return words;
}

export function findExecutable(name: string): string | null {
  const pathEnv = process.env.PATH || "";
  for (const dir of pathEnv.split(path.delimiter)) {
    if (!dir) continue;
    const candidate = path.join(dir, name);
    try {
      fs.accessSync(candidate, fs.constants.X_OK);
      const stat = fs.statSync(candidate);
      if (stat.isFile()) return candidate;
    } catch {
      // keep searching
    }
  }
  return null;
}

export async function ask(question: string): Promise<string> {
  const rl = readline.createInterface({ input, output });
  try {
    return (await rl.question(`${colors.blue}>${colors.reset} ${question} `)).trim();
  } finally {
    rl.close();
  }
}

export async function readSingleKey(): Promise<string> {
  if (!process.stdin.isTTY) return "";
  return await new Promise((resolve) => {
    const stdin = process.stdin;
    const wasRaw = stdin.isRaw;
    stdin.setRawMode(true);
    stdin.resume();
    stdin.once("data", (chunk: Buffer) => {
      stdin.setRawMode(wasRaw);
      stdin.pause();
      resolve(chunk.toString("utf8"));
    });
  });
}

export function copyFile(src: string, dst: string): void {
  ensureDir(path.dirname(dst), "target directory");
  fs.copyFileSync(src, dst);
  const stat = fs.statSync(dst);
  if (!stat.size) throw new Error(`${dst} is empty after copy`);
}
