#!/usr/bin/env bash
# Ask Google Gemini to explain the failed logs and print its answer (Markdown).
# Prints nothing and exits non-zero if the request fails, so the caller can fall back.
#
# usage: ai-explain.sh <prompt-file>
# needs GEMINI_API_KEY (free key from https://aistudio.google.com/apikey), optional GEMINI_MODEL
set -euo pipefail

model=${GEMINI_MODEL:-gemini-3.8-flash}
url="https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent"

body=$(jq -n \
  --rawfile system .github/prompts/explain-failure.txt \
  --rawfile logs "$1" \
  '{
    system_instruction: {parts: [{text: $system}]},
    contents: [{role: "user", parts: [{text: $logs}]}],
    generationConfig: {maxOutputTokens: 4096}
  }')

if ! resp=$(curl -sS --fail-with-body --max-time 90 \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$body" "$url"); then
  echo "Gemini request failed: $(jq -r '.error.message // .' <<< "$resp" 2>/dev/null | head -c 300)" >&2
  exit 1
fi

answer=$(jq -r '[.candidates[0].content.parts[]?.text // empty] | join("")' <<< "$resp")
if [ -z "$answer" ]; then
  echo "Gemini returned no text (finishReason: $(jq -r '.candidates[0].finishReason // "unknown"' <<< "$resp"))" >&2
  exit 1
fi

printf '%s\n' "$answer"
