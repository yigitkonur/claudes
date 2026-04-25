export type RemapMode = "warp" | "all" | "none";

export interface PresetConfig {
  flags?: string;
  description?: string;
  alias?: string;
  prompt?: string;
  mcp?: string;
  env?: Record<string, string>;
}

export interface FileConfig {
  ux?: {
    order?: string[];
    default?: string;
    remap?: RemapMode;
    commands?: string[];
  };
  presets?: Record<string, PresetConfig>;
  remove_builtins?: string[];
}

export interface RuntimePreset {
  name: string;
  flags: string;
  description: string;
  alias?: string;
  prompt?: string;
  mcp?: string;
  env?: Record<string, string>;
  builtin: boolean;
}

export interface RuntimeConfig {
  file: FileConfig;
  presets: Map<string, RuntimePreset>;
  aliases: Map<string, string>;
  ux: {
    order: string[];
    default: string;
    remap: RemapMode;
    commands: string[];
  };
}

export interface CliPaths {
  home: string;
  configDir: string;
  configFile: string;
  cacheFile: string;
  installDir: string;
  v2Dir: string;
  zshrc: string;
  zshrcDir: string;
}
