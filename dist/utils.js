"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.colors = void 0;
exports.ok = ok;
exports.info = info;
exports.warn = warn;
exports.err = err;
exports.step = step;
exports.getPaths = getPaths;
exports.ensureDir = ensureDir;
exports.expandHome = expandHome;
exports.packageRoot = packageRoot;
exports.shellQuote = shellQuote;
exports.splitShellWords = splitShellWords;
exports.findExecutable = findExecutable;
exports.ask = ask;
exports.readSingleKey = readSingleKey;
exports.copyFile = copyFile;
const node_fs_1 = __importDefault(require("node:fs"));
const node_os_1 = __importDefault(require("node:os"));
const node_path_1 = __importDefault(require("node:path"));
const promises_1 = __importDefault(require("node:readline/promises"));
const node_process_1 = require("node:process");
exports.colors = process.stdout.isTTY
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
function ok(message) {
    console.log(`${exports.colors.green}[ok]${exports.colors.reset} ${message}`);
}
function info(message) {
    console.log(`${exports.colors.blue}[..]${exports.colors.reset} ${message}`);
}
function warn(message) {
    console.log(`${exports.colors.yellow}[!!]${exports.colors.reset} ${message}`);
}
function err(message) {
    console.error(`${exports.colors.red}[err]${exports.colors.reset} ${message}`);
}
function step(message) {
    console.log(`\n${exports.colors.bold}${message}${exports.colors.reset}\n`);
}
function getPaths() {
    const home = node_os_1.default.homedir();
    const configBase = process.env.XDG_CONFIG_HOME || node_path_1.default.join(home, ".config");
    const configDir = node_path_1.default.join(configBase, "claudes");
    const installDir = node_path_1.default.join(home, ".local", "share", "claudes");
    const v2Dir = node_path_1.default.join(installDir, "v2");
    return {
        home,
        configDir,
        configFile: node_path_1.default.join(configDir, "claudes.yaml"),
        cacheFile: node_path_1.default.join(configDir, ".claudes-cache.json"),
        installDir,
        v2Dir,
        zshrc: node_path_1.default.join(home, ".zshrc"),
        zshrcDir: node_path_1.default.join(home, ".zshrc.d"),
    };
}
function ensureDir(dir, label) {
    try {
        node_fs_1.default.mkdirSync(dir, { recursive: true });
    }
    catch (error) {
        throw new Error(`Failed to create ${label}: ${dir}\n${String(error)}`);
    }
    const stat = node_fs_1.default.statSync(dir);
    if (!stat.isDirectory())
        throw new Error(`${label} is not a directory: ${dir}`);
    node_fs_1.default.accessSync(dir, node_fs_1.default.constants.W_OK);
}
function expandHome(value) {
    if (value === "~")
        return node_os_1.default.homedir();
    if (value.startsWith("~/"))
        return node_path_1.default.join(node_os_1.default.homedir(), value.slice(2));
    return value;
}
function packageRoot() {
    return node_path_1.default.resolve(__dirname, "..");
}
function shellQuote(value) {
    return `'${value.replace(/'/g, `'\\''`)}'`;
}
function splitShellWords(inputText) {
    const words = [];
    let current = "";
    let quote = null;
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
    if (escaping)
        current += "\\";
    if (quote)
        throw new Error("Unterminated quote in flags");
    if (current)
        words.push(current);
    return words;
}
function findExecutable(name) {
    const pathEnv = process.env.PATH || "";
    for (const dir of pathEnv.split(node_path_1.default.delimiter)) {
        if (!dir)
            continue;
        const candidate = node_path_1.default.join(dir, name);
        try {
            node_fs_1.default.accessSync(candidate, node_fs_1.default.constants.X_OK);
            const stat = node_fs_1.default.statSync(candidate);
            if (stat.isFile())
                return candidate;
        }
        catch {
            // keep searching
        }
    }
    return null;
}
async function ask(question) {
    const rl = promises_1.default.createInterface({ input: node_process_1.stdin, output: node_process_1.stdout });
    try {
        return (await rl.question(`${exports.colors.blue}>${exports.colors.reset} ${question} `)).trim();
    }
    finally {
        rl.close();
    }
}
async function readSingleKey() {
    if (!process.stdin.isTTY)
        return "";
    return await new Promise((resolve) => {
        const stdin = process.stdin;
        const wasRaw = stdin.isRaw;
        stdin.setRawMode(true);
        stdin.resume();
        stdin.once("data", (chunk) => {
            stdin.setRawMode(wasRaw);
            stdin.pause();
            resolve(chunk.toString("utf8"));
        });
    });
}
function copyFile(src, dst) {
    ensureDir(node_path_1.default.dirname(dst), "target directory");
    node_fs_1.default.copyFileSync(src, dst);
    const stat = node_fs_1.default.statSync(dst);
    if (!stat.size)
        throw new Error(`${dst} is empty after copy`);
}
