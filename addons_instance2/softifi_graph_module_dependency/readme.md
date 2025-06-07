Graph Module for Odoo
This module offers an interactive graph visualization of Odoo modules using the Owl framework and vis.js library. It helps users quickly explore module dependencies, statuses, and more by displaying nodes and edges that represent modules and their relationships.

Features
Interactive Graph View:
Visualizes module dependencies using a network graph. Double-click a node to view the module’s form, right-click to remove a node.

Module Filtering:
Provides filtering tools based on module states, categories, application flags, and custom domains. Users can search modules by name or description.

Dynamic Data Loading:
Loads module information using Odoo’s ORM service, fetching fields such as name, shortdesc, state, category_id, and icons.

Customizable Appearance:
Uses a default set of state colors and icons, which you can override as needed. Graph node appearance (size, shape, margins) is configurable via the module’s constants.

Dependency Direction Toggle:
Switch between analyzing dependencies (depends_on) or reverse dependencies (depended_by) to better understand module interrelations.

Graph Options Configuration:
Allows customization of the depth of the graph and specifies stop conditions (e.g., stopping when an installed module or a specific category is encountered).

Prerequisites
Odoo Framework:
Ensure you are running a compatible version of Odoo that supports Owl and client action registry.

Internet Access:
The module loads the vis.js library and its CSS from the CDN. A stable internet connection is required.

Installation
Clone or Copy the Module:

Place the module directory in your Odoo addons folder:

bash
Copy
Edit
cp -R path/to/graph_module /path/to/odoo/addons/
Note: Replace graph_module with the actual folder name containing your module.

Update the App List:

In your Odoo instance, go to Apps.

Click on Update Apps List to refresh the module registry.

Install the Module:

Search for the Graph Module in the Apps list.

Click Install to deploy the module.

Usage
Access the Graph Interface:

Navigate to the module’s menu from the Odoo dashboard.

The interface displays a network graph of available modules.

Interacting With the Graph:

Double-click on a node to open the form view of that module.

Right-click on a node to remove it from the graph.

Use the search input to filter nodes by module name or description.

Toggle filters (state, category, application, and module type) to control which modules are displayed.

Adjust Graph Settings:

Configure the maximum graph depth, dependency direction (e.g., modules that “depend on” or “are depended by” a given module), and stop conditions (e.g., stop on installed modules or specified categories).

Module Structure
JavaScript Component (GraphModuleComponent):
The core component built with Owl which renders the graph. It integrates with the Odoo action system and uses dynamic events to manage node selection, update filters, and fetch dependency data.

Assets and Dependencies:

vis.js: Loaded via CDN for rendering the graph.

Owl Framework: Used for component and state management.

Odoo ORM Service: Retrieves module data, ensuring the graph is up-to-date with current module statuses.

Customization
Default Colors and Icons:
Modify DEFAULT_STATE_COLOR and DEFAULT_MODULE_ICON in the source file to align with your branding or design requirements.

Network Options:
Adjust properties in DEFAULT_NETWORK_OPTIONS to change node size, shape, and overall layout behavior.

Filter and Domain Customization:
The module supports custom filtering via state, category, and application flags. You can extend the filtering logic in the updateDomain method as needed.

Troubleshooting
Graph Not Displaying:
Ensure that the vis.js library is accessible from your network. Check your browser’s console for any errors related to asset loading or API calls.

Module Data Not Loading:
Verify that your Odoo environment has the required permissions and that the ir.module.module model is returning the expected fields.

Contributing
Contributions are welcome! If you find issues, have suggestions, or want to extend the functionality, please create an issue or submit a pull request in the module’s repository.

License
Specify the license under which this module is published (e.g., AGPL-3, LGPL, MIT). Make sure it is compatible with your use case and any modifications you plan to make.
