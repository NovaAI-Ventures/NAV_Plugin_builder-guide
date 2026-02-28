#!/usr/bin/env bash
# Setup hook — checks required environment variables

PLUGIN_NAME="PLUGIN_NAME"
MISSING=()
[ -z "${PLUGIN_NAME_UPPER_MCP_API_KEY:-}" ] && MISSING+=("PLUGIN_NAME_UPPER_MCP_API_KEY")

if [ ${#MISSING[@]} -gt 0 ]; then
  VARS_LIST=""
  for v in "${MISSING[@]}"; do
    VARS_LIST="${VARS_LIST}  ${v}=your_value_here\n"
  done
  echo "{\"status\":\"success\",\"systemMessage\":\"[$PLUGIN_NAME] needs these env vars in .env.local:\\n${VARS_LIST}See .env.example for details.\"}"
else
  echo "{\"status\":\"success\",\"systemMessage\":\"[$PLUGIN_NAME]: All credentials configured.\"}"
fi
