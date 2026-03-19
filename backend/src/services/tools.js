/**
 * Tool definitions for Azure AI Foundry function/tool calling.
 * Each tool has a schema (sent to the model) and a handler (executed server-side).
 *
 * Add your custom tools here following the same pattern.
 */

const toolDefinitions = [
  {
    type: "function",
    function: {
      name: "get_current_time",
      description: "Get the current date and time in a given timezone",
      parameters: {
        type: "object",
        properties: {
          timezone: {
            type: "string",
            description:
              "The IANA timezone string, e.g. 'America/New_York', 'Europe/London'",
          },
        },
        required: ["timezone"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "calculate",
      description:
        "Evaluate a simple mathematical expression and return the result",
      parameters: {
        type: "object",
        properties: {
          expression: {
            type: "string",
            description:
              "A mathematical expression to evaluate, e.g. '2 + 2', '10 * 5'",
          },
        },
        required: ["expression"],
      },
    },
  },
];

/**
 * Map of tool name → handler function.
 * Each handler receives the parsed arguments object and returns a string result.
 */
const toolHandlers = {
  get_current_time({ timezone }) {
    try {
      const now = new Date();
      const formatted = now.toLocaleString("en-US", { timeZone: timezone });
      return JSON.stringify({ timezone, datetime: formatted });
    } catch {
      return JSON.stringify({ error: `Invalid timezone: ${timezone}` });
    }
  },

  calculate({ expression }) {
    try {
      // Simple safe math evaluation (no eval)
      const sanitized = expression.replace(/[^0-9+\-*/().%\s]/g, "");
      if (!sanitized || sanitized !== expression.trim()) {
        return JSON.stringify({ error: "Invalid expression" });
      }
      const result = Function(`"use strict"; return (${sanitized})`)();
      return JSON.stringify({ expression, result });
    } catch {
      return JSON.stringify({ error: `Failed to evaluate: ${expression}` });
    }
  },
};

/**
 * Execute a tool call returned by the model.
 * @param {string} name - Tool function name
 * @param {string} argsJson - JSON string of arguments
 * @returns {string} Result string to send back to the model
 */
function executeTool(name, argsJson) {
  const handler = toolHandlers[name];
  if (!handler) {
    return JSON.stringify({ error: `Unknown tool: ${name}` });
  }
  try {
    const args = JSON.parse(argsJson);
    return handler(args);
  } catch {
    return JSON.stringify({ error: `Failed to parse arguments for ${name}` });
  }
}

module.exports = { toolDefinitions, executeTool };
