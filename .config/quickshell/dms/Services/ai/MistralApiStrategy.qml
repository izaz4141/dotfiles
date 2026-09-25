import QtQuick

ApiStrategy {
    property bool isReasoning: false

    function buildEndpoint(model: AiModel): string {
        return model.endpoint;
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let baseData = {
            "model": model.model,
            "messages": [
                {role: "system", content: systemPrompt},
                ...messages.map(message => {
                    const hasFunctionCall = message.functionCall != undefined && message.functionName.length > 0
                    let messageData = {
                        "role": message.role,
                        "content": message.rawContent,
                    }
                    if (hasFunctionCall) {
                        if (message.functionResponse?.length > 0) {
                            messageData.name = message.functionName;
                            messageData.role = "tool";
                            messageData.content = message.functionResponse;
                            messageData.tool_call_id = message.functionCall.id
                        }
                    }
                    return messageData
                }),
            ],
            "stream": true,
            "temperature": temperature,
            "tools": tools,
        };
        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    function parseResponseLine(line, message) {
        let cleanData = line.trim();
        if (cleanData.startsWith("data:")) {
            cleanData = cleanData.slice(5).trim();
        }

        if (!cleanData || cleanData.startsWith(":")) return {};
        if (cleanData === "[DONE]") {
            return { finished: true };
        }

        try {
            const dataJson = JSON.parse(cleanData);

            if (dataJson.error) {
                const errorMsg = `**Error**: ${dataJson.error.message || JSON.stringify(dataJson.error)}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }

            let newContent = "";

            const responseContent = dataJson.choices[0]?.delta?.content || dataJson.message?.content;
            const responseReasoning = dataJson.choices[0]?.delta?.reasoning || dataJson.choices[0]?.delta?.reasoning_content;

            if (dataJson.choices[0]?.delta?.tool_calls) {
                const functionCall = dataJson.choices[0].delta.tool_calls[0];
                const functionName = functionCall.function.name;
                const functionArgs = functionCall.function.arguments ? JSON.parse(functionCall.function.arguments) : {};
                const functionId = functionCall.id;
                const newContent = `\n\n[[ Function: ${functionName}(${JSON.stringify(functionArgs, null, 2)}) ]]\n`;
                message.rawContent += newContent;
                message.content += newContent;
                message.functionName = functionName;
                message.functionCall = functionName;
                return { functionCall: { name: functionName, args: functionArgs, id: functionId } };
            }

            if (responseContent && responseContent.length > 0) {
                if (isReasoning) {
                    isReasoning = false;
                    const endBlock = "\n\n response\n\n";
                    message.content += endBlock;
                    message.rawContent += endBlock;
                }
                newContent = responseContent;
            } else if (responseReasoning && responseReasoning.length > 0) {
                if (!isReasoning) {
                    isReasoning = true;
                    const startBlock = "\n\n thinking\n\n";
                    message.rawContent += startBlock;
                    message.content += startBlock;
                }
                newContent = responseReasoning;
            }

            message.content += newContent;
            message.rawContent += newContent;

            if (dataJson.usage) {
                return {
                    tokenUsage: {
                        input: dataJson.usage.prompt_tokens ?? -1,
                        output: dataJson.usage.completion_tokens ?? -1,
                        total: dataJson.usage.total_tokens ?? -1
                    }
                };
            }

            if (dataJson.done) {
                return { finished: true };
            }

        } catch (e) {
            console.log("[AI] Mistral: Could not parse line: ", e);
            message.rawContent += line;
            message.content += line;
        }

        return {};
    }

    function onRequestFinished(message) {
        return {};
    }

    function reset() {
        isReasoning = false;
    }
}