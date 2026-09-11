// Companion to the verbatim Herdr hook: native Pi waiting spans share its
// counted channel with extension-owned blockers. No socket access here.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
  let rootTui = false;
  let waiting = false;

  const endPrompt = () => {
    if (!waiting) return;
    waiting = false;
    pi.events.emit("herdr:blocked", { active: false });
  };

  pi.on("session_start", (_event, ctx) => {
    rootTui = ctx.mode === "tui";
  });
  pi.on("ui_prompt_start", (event, ctx) => {
    // Pi coalesces nested/overlapping prompts into one outer waiting span.
    if (!rootTui || ctx.mode !== "tui" || waiting) return;
    waiting = true;
    pi.events.emit("herdr:blocked", { active: true, label: event.title });
  });
  pi.on("ui_prompt_end", (_event, ctx) => {
    if (rootTui && ctx.mode === "tui") endPrompt();
  });
  pi.on("session_shutdown", () => {
    endPrompt();
    rootTui = false;
  });
}
