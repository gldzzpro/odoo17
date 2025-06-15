# -*- coding: utf-8 -*-
{
    "name": "Softifi Graph Module Dependency",
    "summary": "Visualize and explore Odoo module dependencies with an interactive network graph.",
    "description": """
        The Graph Module Dependency addon leverages Owl and vis.js to present a dynamic visualization
        of module relationships and dependencies within your Odoo installation.
        
        **Key Features:**
          - Interactive graph view of module dependencies.
          - Real-time filtering based on module state, category, and custom criteria.
          - Intuitive user interactions: double-click to open module details and right-click to remove nodes.
          - Customizable settings for graph depth, dependency direction, and visual styling.
        
        With a modern and responsive design, this addon makes understanding module interrelations more efficient.
    """,
    "author": "Farhat BAAROUN",
    "website": "https://github.com/GldzzPro/graph_module_dependency",
    "category": "Tools",
    "version": "17.0.1.0.0",
    "depends": [
        "base",
        "web",
        "base_setup"
    ],
    "data": [
        "security/ir.model.access.csv",
        "security/module_security.xml", 
        "views/dependency_menus.xml",
    ],
    "assets": {
        "web.assets_backend": [
            "softifi_graph_module_dependency/static/src/components/module_graph/GraphModuleComponent.js",
            "softifi_graph_module_dependency/static/src/components/model_graph/GraphModelComponent.js",
            "softifi_graph_module_dependency/static/src/components/module_graph/module_graph.xml",
            "softifi_graph_module_dependency/static/src/components/model_graph/model_graph.scss",
            "softifi_graph_module_dependency/static/src/components/module_graph/module_graph.scss",
            "softifi_graph_module_dependency/static/src/components/model_graph/model_graph.xml",
        ],
    },
    "images": ["static/description/banner.png"],
    "license": "AGPL-3",
    "installable": True,
    "application": False,
}
