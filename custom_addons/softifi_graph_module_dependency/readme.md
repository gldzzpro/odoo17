# Softifi Graph Module Dependency for Odoo

This module offers an interactive graph visualization of Odoo modules and their dependencies using the Owl framework and vis.js library. It helps users quickly explore module dependencies, statuses, and relationships by displaying nodes and edges that represent modules and their connections.

## Features

### Interactive Graph View
- Visualizes module dependencies using a network graph
- Double-click a node to view the module's form
- Right-click to remove a node from the graph
- Intuitive navigation with zoom and pan controls

### Module Filtering
- Filter modules based on state (installed, uninstalled, to upgrade, etc.)
- Filter by category or application flag
- Search modules by name or description
- Apply custom domains for advanced filtering

### Dynamic Data Loading
- Loads module information using Odoo's ORM service
- Fetches fields such as name, shortdesc, state, category_id, and icons
- Real-time updates when module states change

### Customizable Appearance
- Default state colors and icons that can be overridden
- Configurable graph node appearance (size, shape, margins)
- Visual indicators for module states and relationships

### Dependency Direction Toggle
- Switch between analyzing dependencies (depends_on) or reverse dependencies (depended_by)
- Understand both what a module requires and what depends on it

### Graph Options Configuration
- Customize the depth of the graph traversal
- Specify stop conditions (e.g., stopping when an installed module is encountered)
- Control which categories to include or exclude

## API Controllers and Endpoints

The module exposes several API endpoints that allow programmatic access to the dependency graph data. These endpoints can be used to integrate the graph functionality into other modules or external systems.

### Main Controllers

The module provides two main controller classes:

1. **GraphAPI** - JSON-RPC endpoints with `/api/graph/` prefix
2. **ModuleGraphController** - JSON-RPC endpoints with `/graph_module_dependency/` prefix

### Available Endpoints

#### Module Graph Endpoints

- **`/api/graph/module`** (JSON-RPC)
  - Get module dependency graph data
  - Parameters:
    - `module_ids`: List of module IDs
    - `options`: Dictionary of graph options

- **`/api/graph/reverse`** (JSON-RPC)
  - Get reverse module dependency graph data
  - Parameters:
    - `module_ids`: List of module IDs
    - `options`: Dictionary of graph options

- **`/graph_module_dependency/module_graph`** (JSON-RPC)
  - Public route to get the dependency graph for given module IDs
  - Parameters:
    - `module_ids`: List of integers representing module IDs
    - `options`: Optional dictionary for graph building options

- **`/graph_module_dependency/reverse_module_graph`** (JSON-RPC)
  - Public route to get the reverse dependency graph for given module IDs
  - Parameters:
    - `module_ids`: List of integers representing module IDs
    - `options`: Optional dictionary for graph building options

#### Category-Based Graph Endpoints

- **`/api/graph/category`** (JSON-RPC)
  - Get module dependency graph data for modules matching category prefixes
  - Parameters:
    - `category_prefixes`: List of category prefixes to match (e.g. ['custom/hr', 'custom-hr'])
    - `options`: Dictionary of options controlling graph behavior

- **`/api/graph/category/reverse`** (JSON-RPC)
  - Get reverse module dependency graph data for modules matching category prefixes
  - Parameters:
    - `category_prefixes`: List of category prefixes to match
    - `options`: Dictionary of options controlling graph behavior

- **`/graph_module_dependency/category_module_graph`** (JSON-RPC)
  - Public route to get the dependency graph for modules matching category prefixes
  - Parameters:
    - `category_prefixes`: List of strings representing category prefixes to match
    - `options`: Optional dictionary for graph building options

- **`/graph_module_dependency/reverse_category_module_graph`** (JSON-RPC)
  - Public route to get the reverse dependency graph for modules matching category prefixes
  - Parameters:
    - `category_prefixes`: List of strings representing category prefixes to match
    - `options`: Optional dictionary for graph building options

#### Model Graph Endpoints

- **`/api/graph/model`** (JSON-RPC)
  - Get model relation graph data
  - Parameters:
    - `model_ids`: List of model IDs
    - `options`: Dictionary containing options like max_depth

### Graph Options

The following options can be passed to the graph endpoints:

- `max_depth`: Maximum depth to traverse in the graph (integer)
- `stop_domains`: List of domains to stop traversal (e.g., stop on installed modules)
- `exclude_domains`: List of domains to exclude modules from the graph
- `exact_match`: For category endpoints, if True, only match exact category names, not prefixes
- `include_subcategories`: For category endpoints, if True, include modules from subcategories
- `include_relations`: Whether to include relation edges (boolean, default True)
- `include_exclusions`: Whether to include exclusion edges (boolean, default True)

## How to Use the API

### Example: Fetching Module Dependencies

```python
# Using the Odoo RPC API
import xmlrpc.client

# Connect to Odoo
url = 'http://localhost:8069'
db = 'your_database'
username = 'your_username'
password = 'your_password'



# Get the API endpoint
models = xmlrpc.client.ServerProxy('{}/xmlrpc/2/object'.format(url))

# Get module IDs (example: get the 'base' module ID)
base_module_id = models.execute_kw(db, uid, password,
    'ir.module.module', 'search',
    [[['name', '=', 'base']]]
)

# Call the graph API
options = {
    'max_depth': 2,
    'stop_domains': [["state", "=", "installed"]]
}

graph_data = models.execute_kw(db, uid, password,
    'ir.module.module', 'get_module_graph',
    [base_module_id, options]
)

# Process the graph data
print(f"Found {len(graph_data['nodes'])} nodes and {len(graph_data['edges'])} edges")
```

### Example: Using curl with JSON-RPC

```bash
# Using curl to call the module graph API

# Set the base URL for your Odoo instance
BASE_URL="http://localhost:8069"

# Define the endpoint for module graph
MODULE_GRAPH_ENDPOINT="$BASE_URL/graph_module_dependency/module_graph"

# Example: Get dependency graph for the base module (ID: 1)
curl -s -X POST "$MODULE_GRAPH_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "module_ids": [1],
      "options": {
        "max_depth": 2,
        "stop_domains": [["state", "=", "installed"]]
      }
    },
    "id": 123456
  }'

# To process the response with jq (if installed)
# curl -s -X POST "$MODULE_GRAPH_ENDPOINT" ... | jq '.result'

# Example: Get reverse dependency graph
REVERSE_GRAPH_ENDPOINT="$BASE_URL/graph_module_dependency/reverse_module_graph"

curl -s -X POST "$REVERSE_GRAPH_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "module_ids": [1],
      "options": {
        "max_depth": 2
      }
    },
    "id": 123456
  }'
```

## Prerequisites

### Odoo Framework
- Ensure you are running Odoo 17.0 or compatible version that supports Owl and client action registry

### Internet Access
- The module loads the vis.js library and its CSS from the CDN
- A stable internet connection is required for initial loading

## Installation

1. **Clone or Copy the Module**
   ```bash
   cp -R path/to/softifi_graph_module_dependency /path/to/odoo/addons/
   ```

2. **Update the App List**
   - In your Odoo instance, go to Apps
   - Click on Update Apps List to refresh the module registry

3. **Install the Module**
   - Search for "Softifi Graph Module Dependency" in the Apps list
   - Click Install to deploy the module

## License

This module is published under the AGPL-3 license, as specified in the module's manifest.
