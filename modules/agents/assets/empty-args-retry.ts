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
        `provider returned error: tool call for "${name}" arrived with an empty ` +
        `arguments payload (required: ${needs}); treated as transient and retried`,
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
