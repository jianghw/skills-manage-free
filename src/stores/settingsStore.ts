import { create } from "zustand";
import { invoke } from "@tauri-apps/api/core";
import { ScanDirectory, AgentWithStatus, CustomAgentConfig, UpdateCustomAgentConfig } from "@/types";

// ─── State ────────────────────────────────────────────────────────────────────

interface SettingsState {
  scanDirectories: ScanDirectory[];
  isLoadingScanDirs: boolean;
  error: string | null;
  githubPat: string;
  isLoadingGitHubPat: boolean;
  isSavingGitHubPat: boolean;

  // Proxy settings
  proxyEnabled: boolean;
  proxyUrl: string;
  isLoadingProxySettings: boolean;

  // Actions — scan directories
  loadScanDirectories: () => Promise<void>;
  addScanDirectory: (path: string, label?: string) => Promise<ScanDirectory>;
  removeScanDirectory: (path: string) => Promise<void>;
  toggleScanDirectory: (path: string, active: boolean) => Promise<void>;

  // Actions — GitHub PAT
  loadGitHubPat: () => Promise<void>;
  saveGitHubPat: (value: string) => Promise<void>;
  clearGitHubPat: () => Promise<void>;

  // Actions — custom agents
  addCustomAgent: (config: CustomAgentConfig) => Promise<AgentWithStatus>;
  updateCustomAgent: (agentId: string, config: UpdateCustomAgentConfig) => Promise<AgentWithStatus>;
  removeCustomAgent: (agentId: string) => Promise<void>;

  // Actions — proxy settings
  loadProxySettings: () => Promise<void>;
  setProxyEnabled: (enabled: boolean) => Promise<void>;
  setProxyUrl: (url: string) => Promise<void>;

  clearError: () => void;
}

// ─── Store ────────────────────────────────────────────────────────────────────

export const useSettingsStore = create<SettingsState>((set) => ({
  scanDirectories: [],
  isLoadingScanDirs: false,
  error: null,
  githubPat: "",
  isLoadingGitHubPat: false,
  isSavingGitHubPat: false,

  // Proxy settings initial state
  proxyEnabled: false,
  proxyUrl: "http://127.0.0.1:7897",
  isLoadingProxySettings: false,

  // ── Scan Directories ───────────────────────────────────────────────────────

  /**
   * Load all scan directories from the backend.
   */
  loadScanDirectories: async () => {
    set({ isLoadingScanDirs: true, error: null });
    try {
      const dirs = await invoke<ScanDirectory[]>("get_scan_directories");
      set({ scanDirectories: dirs, isLoadingScanDirs: false });
    } catch (err) {
      set({ error: String(err), isLoadingScanDirs: false });
    }
  },

  /**
   * Add a new custom scan directory.
   * Returns the created ScanDirectory or throws on error.
   */
  addScanDirectory: async (path: string, label?: string) => {
    const dir = await invoke<ScanDirectory>("add_scan_directory", {
      path,
      label: label || null,
    });
    // Refresh the list
    set((state) => ({
      scanDirectories: [...state.scanDirectories, dir],
    }));
    return dir;
  },

  /**
   * Remove a custom scan directory by path.
   */
  removeScanDirectory: async (path: string) => {
    await invoke<void>("remove_scan_directory", { path });
    set((state) => ({
      scanDirectories: state.scanDirectories.filter((d) => d.path !== path),
    }));
  },

  /**
   * Toggle the active state of a custom scan directory.
   * Persists the change to the backend database.
   */
  toggleScanDirectory: async (path: string, active: boolean) => {
    await invoke<void>("set_scan_directory_active", { path, isActive: active });
    set((state) => ({
      scanDirectories: state.scanDirectories.map((d) =>
        d.path === path ? { ...d, is_active: active } : d
      ),
    }));
  },

  // ── GitHub PAT ────────────────────────────────────────────────────────────

  loadGitHubPat: async () => {
    set({ isLoadingGitHubPat: true, error: null });
    try {
      const value = await invoke<string | null>("get_setting", { key: "github_pat" });
      set({
        githubPat: value ?? "",
        isLoadingGitHubPat: false,
      });
    } catch (err) {
      set({
        error: String(err),
        isLoadingGitHubPat: false,
      });
    }
  },

  saveGitHubPat: async (value: string) => {
    set({ isSavingGitHubPat: true, error: null });
    try {
      await invoke("set_setting", { key: "github_pat", value });
      set({
        githubPat: value.trim(),
        isSavingGitHubPat: false,
      });
    } catch (err) {
      set({
        error: String(err),
        isSavingGitHubPat: false,
      });
      throw err;
    }
  },

  clearGitHubPat: async () => {
    set({ isSavingGitHubPat: true, error: null });
    try {
      await invoke("set_setting", { key: "github_pat", value: "" });
      set({
        githubPat: "",
        isSavingGitHubPat: false,
      });
    } catch (err) {
      set({
        error: String(err),
        isSavingGitHubPat: false,
      });
      throw err;
    }
  },

  // ── Custom Agents ──────────────────────────────────────────────────────────

  /**
   * Register a new user-defined agent.
   * Returns the created AgentWithStatus or throws on error.
   */
  addCustomAgent: async (config: CustomAgentConfig) => {
    const agent = await invoke<AgentWithStatus>("add_custom_agent", { config });
    return agent;
  },

  /**
   * Update an existing user-defined agent.
   * Returns the updated AgentWithStatus or throws on error.
   */
  updateCustomAgent: async (agentId: string, config: UpdateCustomAgentConfig) => {
    const agent = await invoke<AgentWithStatus>("update_custom_agent", {
      agentId,
      config,
    });
    return agent;
  },

  /**
   * Remove a user-defined agent by ID.
   */
  removeCustomAgent: async (agentId: string) => {
    await invoke<void>("remove_custom_agent", { agentId });
  },

  // ── Proxy Settings ──────────────────────────────────────────────────────────

  loadProxySettings: async () => {
    set({ isLoadingProxySettings: true, error: null });
    try {
      const enabled = await invoke<string | null>("get_setting", { key: "proxy_enabled" });
      const url = await invoke<string | null>("get_setting", { key: "proxy_url" });
      set({
        proxyEnabled: (enabled ?? "") === "true",
        proxyUrl: url ?? "http://127.0.0.1:7897",
        isLoadingProxySettings: false,
      });
    } catch (err) {
      set({ error: String(err), isLoadingProxySettings: false });
    }
  },

  setProxyEnabled: async (enabled: boolean) => {
    set({ error: null });
    try {
      await invoke("set_setting", { key: "proxy_enabled", value: enabled ? "true" : "false" });
      set({ proxyEnabled: enabled });
    } catch (err) {
      set({ error: String(err) });
      throw err;
    }
  },

  setProxyUrl: async (url: string) => {
    set({ error: null });
    try {
      await invoke("set_setting", { key: "proxy_url", value: url });
      set({ proxyUrl: url });
    } catch (err) {
      set({ error: String(err) });
      throw err;
    }
  },

  // ── Misc ───────────────────────────────────────────────────────────────────

  clearError: () => set({ error: null }),
}));
