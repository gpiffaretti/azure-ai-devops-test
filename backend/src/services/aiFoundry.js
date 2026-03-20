const { AzureOpenAI } = require("openai");
const { DefaultAzureCredential } = require("@azure/identity");
const config = require("../config");
const { toolDefinitions, executeTool } = require("./tools");

/**
 * Azure AI Foundry client singleton.
 * Uses API key for local development, managed identity for Azure deployment.
 */
const client = new AzureOpenAI({
  endpoint: config.aiFoundryEndpoint,
  apiKey: config.aiFoundryApiKey || undefined,
  azureADTokenProvider: config.aiFoundryApiKey 
    ? undefined 
    : async () => {
        const credential = new DefaultAzureCredential();
        const token = await credential.getToken("https://cognitiveservices.azure.com/.default");
        return token.token;
      },
  deployment: config.aiFoundryDeployment,
  apiVersion: config.aiFoundryApiVersion,
});

/**
 * Send a chat completion request with streaming enabled.
 * Handles tool calls by executing them and re-prompting the model.
 *
 * @param {Array} messages - Chat messages array [{role, content}, ...]
 * @param {Function} onChunk  - Callback invoked with each text delta chunk
 * @param {Function} onToolCall - Callback invoked when a tool call is executed
 * @param {AbortSignal} [signal] - Optional abort signal for cancellation
 */
async function streamChatCompletion(messages, onChunk, onToolCall, signal) {
  const conversationMessages = [...messages];
  let continueLoop = true;

  while (continueLoop) {
    continueLoop = false;

    const stream = await client.chat.completions.create(
      {
        model: config.aiFoundryModel,
        messages: conversationMessages,
        tools: toolDefinitions.length > 0 ? toolDefinitions : undefined,
        tool_choice: toolDefinitions.length > 0 ? "auto" : undefined,
        stream: true,
      },
      { signal }
    );

    // Collect tool calls across streamed chunks
    const pendingToolCalls = {};
    let assistantContent = "";
    let hasToolCalls = false;

    for await (const chunk of stream) {
      if (signal?.aborted) {
        throw new Error("Request aborted");
      }

      if (!chunk.choices || chunk.choices.length === 0) continue;

      const delta = chunk.choices[0].delta;
      const finishReason = chunk.choices[0].finish_reason;

      // Accumulate content deltas
      if (delta?.content) {
        assistantContent += delta.content;
        onChunk(delta.content);
      }

      // Accumulate tool call deltas
      if (delta?.tool_calls) {
        for (const tc of delta.tool_calls) {
          const idx = tc.index;
          if (!pendingToolCalls[idx]) {
            pendingToolCalls[idx] = {
              id: tc.id || "",
              name: tc.function?.name || "",
              arguments: "",
            };
          }
          if (tc.id) pendingToolCalls[idx].id = tc.id;
          if (tc.function?.name) pendingToolCalls[idx].name = tc.function.name;
          if (tc.function?.arguments) {
            pendingToolCalls[idx].arguments += tc.function.arguments;
          }
        }
      }

      if (finishReason === "tool_calls") {
        hasToolCalls = true;
      }
    }

    // If the model requested tool calls, execute them and loop
    if (hasToolCalls && Object.keys(pendingToolCalls).length > 0) {
      const toolCallsArray = Object.values(pendingToolCalls).map((tc) => ({
        id: tc.id,
        type: "function",
        function: { name: tc.name, arguments: tc.arguments },
      }));

      // Add assistant message with tool calls
      conversationMessages.push({
        role: "assistant",
        content: assistantContent || null,
        tool_calls: toolCallsArray,
      });

      // Execute each tool and add results
      for (const tc of toolCallsArray) {
        const result = executeTool(tc.function.name, tc.function.arguments);
        onToolCall({ name: tc.function.name, result });

        conversationMessages.push({
          role: "tool",
          tool_call_id: tc.id,
          content: result,
        });
      }

      // Continue the loop to get the model's final response
      continueLoop = true;
    }
  }
}

module.exports = { streamChatCompletion };
