import type { AgentWithStatus } from "@/types";

export const CENTRAL_AGENT_ID = "central";
export const OBSIDIAN_AGENT_ID = "obsidian";

/**
 * Agents that share the same ~/.agents/skills directory as the central agent.
 * These cannot be independently installed/uninstalled — toggling them would
 * try to create a self-referencing symlink (same source and target directory).
 * They are excluded from install-target lists so the UI never offers them
 * as installable platforms for central skills.
 */
const SHARED_CENTRAL_DIR_AGENT_IDS = new Set([
  "antigravity",
  "cline",
  "codex",
  "deep-agents",
  "dexto",
  "firebender",
  "kimi-code-cli",
  "warp",
]);

const NON_INSTALL_TARGET_AGENT_IDS = new Set([
  CENTRAL_AGENT_ID,
  OBSIDIAN_AGENT_ID,
  ...SHARED_CENTRAL_DIR_AGENT_IDS,
]);

export function isInstallTargetAgent(agent: Pick<AgentWithStatus, "id">): boolean {
  return !NON_INSTALL_TARGET_AGENT_IDS.has(agent.id);
}

export function isEnabledInstallTargetAgent(
  agent: Pick<AgentWithStatus, "id" | "is_enabled">
): boolean {
  return isInstallTargetAgent(agent) && agent.is_enabled;
}
