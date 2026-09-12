// Retry provider responses whose tool-call arguments arrive empty.
//
// Fleet evidence (2026-09-12, session logs on thinkpad) and upstream
// earendil-works/pi#5194: zai's GLM tool-call translation intermittently
// drops the arguments of tools whose schema nests an array of objects. The
// toolCall block arrives with its id but `arguments: {}` — observed on
// glm-5.3/glm-5.3-flash for pi's `edit` (39/61 and 13/19 calls), never for
// flat-schema tools (`write`, `bash`, `read`) and never on other providers.
// Pi then fails the call with a misleading schema error and models tend to
// re-emit the identical call, wasting turns.
//
// pi-tool-repair deliberately cannot handle this class: every
// validate-then-repair rule needs present (but malformed) fields, and `{}`
// leaves nothing to repair. This extension instead converts the whole
// response into a transient provider error (stopReason "error" plus a
// descriptive errorMessage), which Pi's built-in agent retry (retry.enabled,
// retry.maxRetries, default 3 attempts) re-issues automatically — the same
// mechanism pi-tool-repair uses for phantom toolUse responses. All toolCall
// blocks are stripped from the returned message so a retried turn never
// leaves unmatched calls in the persisted history (the failure spiral of
// earendil-works/pi#5921).
//
// Deliberately model-agnostic and schema-directed: a call with zero
// arguments against an active tool that declares required properties can
// never execute on any provider, so a bounded retry is always preferable to
// a doomed tool error. Calls for unknown/inactive tools or tools without
// required properties are left for Pi's own handling.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

type AssistantMessage = {
  role: string
  stopReason?: string
  errorMessage?: string
  content?: unknown
}
type ToolLike = { name: string; parameters: unknown }
export type EmptyArgsRetryResult = { changed: boolean; message: AssistantMessage }

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value)

const requiredProperties = (parameters: unknown): string[] => {
  if (!isRecord(parameters)) return []
  const required = parameters.required
  return Array.isArray(required) ? required.filter((entry) => typeof entry === "string") : []
}

const isToolCall = (part: unknown): part is Record<string, unknown> =>
  isRecord(part) && part.type === "toolCall"

const hasEmptyArguments = (call: Record<string, unknown>, required: Map<string, string[]>): boolean => {
  const needs = required.get(call.name)
  if (needs === undefined || needs.length === 0) return false
  const args = call.arguments
  return !isRecord(args) || Object.keys(args).length === 0
}

// Pure transform, exported for the offline extension checks: converts an
// assistant message that contains at least one empty-arguments tool call
// into a retryable error message with every toolCall block removed.
export function retryEmptyArguments(
  message: AssistantMessage,
  tools: readonly ToolLike[],
): EmptyArgsRetryResult {
  if (message.role !== "assistant" || message.stopReason !== "toolUse") {
    return { changed: false, message }
  }
  const content = message.content
  if (!Array.isArray(content)) return { changed: false, message }

  const calls = content.filter(isToolCall)
  if (calls.length === 0) return { changed: false, message }

  const required = new Map(tools.map((tool) => [tool.name, requiredProperties(tool.parameters)]))
  const offender = calls.find((call) => hasEmptyArguments(call, required))
  if (offender === undefined) return { changed: false, message }

  const name = String(offender.name)
  const needs = required.get(name)?.join(", ") ?? ""
  process.stderr.write(
    `[pi-empty-args-retry] tool "${name}" arrived with empty arguments (requires ${needs}); retrying as a transient provider error\n`,
  )
  return {
    changed: true,
    message: {
      ...message,
      content: content.filter((part) => !isToolCall(part)),
      stopReason: "error",
      errorMessage:
        `provider tool call for "${name}" arrived with an empty arguments payload ` +
        `(required: ${needs}); treated as transient and retried`,
    },
  }
}

export default function (pi: ExtensionAPI) {
  const activeToolSchemas = (): ToolLike[] => {
    try {
      const active = new Set(pi.getActiveTools())
      return pi
        .getAllTools()
        .filter((tool) => active.has(tool.name))
        .map((tool) => ({ name: tool.name, parameters: tool.parameters }))
    } catch {
      return []
    }
  }

  pi.on("message_end", (event) => {
    const result = retryEmptyArguments(event.message, activeToolSchemas())
    return result.changed ? { message: result.message } : undefined
  })
}
