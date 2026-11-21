#!/usr/bin/env bash
# Ask Google Gemini to explain the failed logs and print its answer (Markdown).
# Prints nothing and exits non-zero if the request fails, so the caller can fall back.
#
# usage: ai-explain.sh <prompt-file>
# needs GEMINI_API_KEY (free key from https://aistudio.google.com/apikey), optional GEMINI_MODEL
set -euo pipefail

# Free models get busy (HTTP 503) at peak times; when one is busy, the next one usually isn't.
models="${GEMINI_MODEL:-gemini-3.8-flash} gemini-3.6-flash gemini-3.5-flash-lite"

body=$(jq -n \
  --rawfile system .github/prompts/explain-failure.txt \
  --rawfile logs "$1" \
  '{
    system_instruction: {parts: [{text: $system}]},
    contents: [{role: "user", parts: [{text: $logs}]}],
    generationConfig: {maxOutputTokens: 4096}
  }')

ask() {
  local url="https://generativelanguage.googleapis.com/v1beta/models/$1:generateContent"
  curl -sS --max-time 90 -w '\n%{http_code}' \
    -H "x-goog-api-key: $GEMINI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$body" "$url" || printf '\n000'
}

code=000
for model in $(tr ' ' '\n' <<< "$models" | awk 'NF && !seen[$0]++'); do
  for attempt in 1 2; do
    resp=$(ask "$model")
    code=${resp##*$'\n'}
    resp=${resp%$'\n'*}
    [ "$code" = 200 ] && break 2

    echo "$model attempt $attempt: HTTP $code $(jq -r '.error.message // empty' <<< "$resp" 2>/dev/null | head -c 300)" >&2
    case $code in
      429 | 500 | 503 | 000) [ "$attempt" = 1 ] && sleep 10 ;; # busy: wait once, then next model
      404) break ;;                                             # unknown model name: next model
      *) exit 1 ;;                                              # e.g. 400 wrong key: no point retrying
    esac
  done
done
[ "$code" = 200 ] || exit 1

answer=$(jq -r '[.candidates[0].content.parts[]?.text // empty] | join("")' <<< "$resp")
if [ -z "$answer" ]; then
  echo "Gemini returned no text (finishReason: $(jq -r '.candidates[0].finishReason // "unknown"' <<< "$resp"))" >&2
  exit 1
fi

echo "Answered by $model" >&2
printf '%s\n' "$answer"
