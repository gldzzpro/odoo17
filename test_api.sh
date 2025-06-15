#!/bin/bash
#
# test_odoo_jsonRpc_controllers.sh
#
# Test script for Odoo JSON‑RPC Graph Controllers using only the exposed
# /api/graph/* endpoints. 
#
# Workflow:
#   1. Test basic connectivity to the API endpoints
#   2. Test category-based endpoint
#   3. Test module and reverse graph endpoints with sample data
#
# Requirements:
#   - curl (standard on most systems)
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

echo -e "${BLUE}=== Step 1: Test category endpoint ===${NC}"
# Test the category-based JSON‑RPC endpoint
echo -e "${GREEN}Testing category endpoint with 'Custom' prefix...${NC}"
curl -s -X POST "$CATEGORY_RPC" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "category_prefixes": ["Custom"],
      "options": {
        "exact_match": false,
        "include_subcategories": true,
        "max_depth": 0
      }
    },
    "id": null
  }'
echo ""
echo -e "${BLUE}-----------------------------------------------------${NC}"

# Use sample module IDs for testing (common Odoo modules)
MODULE_IDS_CSV="[1, 2, 3]"
echo -e "${GREEN}Using sample module IDs for testing: $MODULE_IDS_CSV${NC}"

echo -e "${BLUE}=== Step 2: Test module graph endpoint ===${NC}"

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
  }'
echo ""
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
  }'
echo ""
echo -e "${BLUE}-----------------------------------------------------${NC}"

# Test C: Forward graph with stop_domains
echo -e "${GREEN}Test C: Forward graph (with stop_domains)${NC}"
curl -s -X POST "$MODULE_RPC" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "module_ids": '"$MODULE_IDS_CSV"',
      "options": {
        "stop_domains": [[["id","=",1]]]
      }
    },
    "id": null
  }'
echo ""
echo -e "${BLUE}-----------------------------------------------------${NC}"

echo -e "${BLUE}=== Step 3: Test reverse graph endpoint ===${NC}"

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
  }'
echo ""
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
  }'
echo ""
echo -e "${BLUE}-----------------------------------------------------${NC}"

echo -e "${GREEN}All JSON‑RPC graph controller tests completed.${NC}"
