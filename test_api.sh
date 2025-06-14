#!/bin/bash
#
# test_odoo_jsonRpc_controllers.sh
#
# Test script for Odoo JSON‑RPC Graph Controllers using only the exposed
# /api/graph/* endpoints. 
#
# Workflow:
#   1. Retrieve all modules whose category names contain "Tools" via
#      the category-based JSON‑RPC endpoint with max_depth=0.
#   2. Extract the module IDs from that response.
#   3. Test forward and reverse graphs for those modules under various options.
#
# Requirements:
#   - jq (for JSON parsing)
#   - Odoo running at localhost:8069 with the GraphAPI JSON‑RPC controllers loaded
#
# Usage:
#   chmod +x test_odoo_jsonRpc_controllers.sh
#   ./test_odoo_jsonRpc_controllers.sh

BASE_URL="http://localhost:8069" 
CATEGORY_RPC="$BASE_URL/api/graph/category"
MODULE_RPC="$BASE_URL/api/graph/module"
REVERSE_RPC="$BASE_URL/api/graph/reverse"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Step 1: Fetch modules in categories matching 'Tools' ===${NC}"
# We call the category-based JSON‑RPC with max_depth=0 to get only the module nodes.
category_response=$(curl -s -X POST "$CATEGORY_RPC" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "category_prefixes": ["Tools"],
      "options": {
        "exact_match": false,
        "include_subcategories": true,
        "max_depth": 0
      }
    },
    "id": null
  }')

echo "$category_response" | jq .

# Extract module IDs from the result.nodes array, safely handling empty arrays
module_ids=($(echo "$category_response" | jq -r '.result.nodes[] | .id' 2>/dev/null || echo ""))
if [ -z "${module_ids[*]}" ]; then
  echo -e "${YELLOW}No modules found in 'Tools' categories. Aborting tests.${NC}"
  exit 1
fi

echo -e "${GREEN}Found module IDs:${NC}" "${module_ids[@]}"
echo -e "${BLUE}-----------------------------------------------------${NC}"

# Convert array to comma-separated string for payloads
MODULE_IDS_CSV=$(printf "%s," "${module_ids[@]}")
MODULE_IDS_CSV="[${MODULE_IDS_CSV%,}]"

first_module=${module_ids[0]}

echo -e "${BLUE}=== Step 2: Forward graph for modules in 'Tools' categories ===${NC}"

# Test A: Basic forward graph (no options)
echo -e "${GREEN}Test A: Forward graph (no options)${NC}"
curl -s -X POST "$MODULE_RPC" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "module_ids": '"$MODULE_IDS_CSV"',
      "options": {}
    },
    "id": null
  }' | jq .
echo -e "${BLUE}-----------------------------------------------------${NC}"

# Test B: Forward graph with max_depth = 2
echo -e "${GREEN}Test B: Forward graph (max_depth=2)${NC}"
curl -s -X POST "$MODULE_RPC" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "module_ids": '"$MODULE_IDS_CSV"',
      "options": {
        "max_depth": 2
      }
    },
    "id": null
  }' | jq .
echo -e "${BLUE}-----------------------------------------------------${NC}"

# Test C: Forward graph with stop_domains on the first module ID
echo -e "${GREEN}Test C: Forward graph (stop_domains on module ${first_module})${NC}"
curl -s -X POST "$MODULE_RPC" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "module_ids": '"$MODULE_IDS_CSV"',
      "options": {
        "stop_domains": [[["id","=",'"${first_module}"']]]
      }
    },
    "id": null
  }' | jq .
echo -e "${BLUE}-----------------------------------------------------${NC}"

echo -e "${BLUE}=== Step 3: Reverse graph for modules in 'Tools' categories ===${NC}"

# Test D: Basic reverse graph (no options)
echo -e "${GREEN}Test D: Reverse graph (no options)${NC}"
curl -s -X POST "$REVERSE_RPC" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "module_ids": '"$MODULE_IDS_CSV"',
      "options": {}
    },
    "id": null
  }' | jq .
echo -e "${BLUE}-----------------------------------------------------${NC}"

# Test E: Reverse graph with max_depth = 1
echo -e "${GREEN}Test E: Reverse graph (max_depth=1)${NC}"
curl -s -X POST "$REVERSE_RPC" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "module_ids": '"$MODULE_IDS_CSV"',
      "options": {
        "max_depth": 1
      }
    },
    "id": null
  }' | jq .
echo -e "${BLUE}-----------------------------------------------------${NC}"

echo -e "${GREEN}All JSON‑RPC graph controller tests completed.${NC}"
