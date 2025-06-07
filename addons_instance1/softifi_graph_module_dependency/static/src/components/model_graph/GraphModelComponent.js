/** @odoo-module */
import { Component, useState, useRef, onWillStart, onMounted } from "@odoo/owl";
import { useService } from "@web/core/utils/hooks";
import { registry } from '@web/core/registry';
import { loadJS, loadCSS } from "@web/core/assets";

export class GraphModelComponent extends Component {
    static template = "model_graph_template"; // Refers to our QWeb template

    static props = {};

    setup() {
        this.state = useState({
            nodes: [],
            edges: [],
            model_info: {},
            filteredNodes: [],
            selectedModels: new Set(),
            maxDepth: 2, // Default max depth
            relationTypeColors: {
                'many2one': '#ff0000',
                'one2one': '#97c2fc',
                'one2many': '#AEFCAB',
                'many2many': '#fcadb7',
            },
            modelModules: {}, // Map of model IDs to their module information
            showIcons: true, // Toggle for displaying icons
        });

        this.graphNodes = null;
        this.graphEdges = null;
        this.network = null;

        this.containerRef = useRef("graph");
        this.orm = useService("orm");
        this.action = useService("action");

        onWillStart(async () => {
            // Load vis.js library
            await loadJS("https://cdnjs.cloudflare.com/ajax/libs/vis/4.21.0/vis.min.js");
            await loadCSS("https://cdnjs.cloudflare.com/ajax/libs/vis/4.21.0/vis.min.css");

            // Fetch model data with module information
            const data = await this.orm.call(
                'ir.model',
                'search_read',
                [],
                {
                    fields: ['id', 'name', 'model', 'modules'],
                    order: 'name',
                }
            );

            // Fetch module data to get icons
            const moduleData = await this.orm.call(
                'ir.module.module',
                'search_read',
                [],
                {
                    fields: ['id', 'name', 'shortdesc', 'icon', 'icon_image'],
                }
            );

            // Create a map of module names to their icons
            const moduleIcons = {};
            moduleData.forEach(module => {
                moduleIcons[module.name] = {
                    icon: module.icon || `/base/static/img/icons/default_module_icon.png`,
                    shortdesc: module.shortdesc
                };
            });

            // Process model data and associate with modules
            this.state.nodes = data.map(node => {
                // Get the first module that provides this model
                const moduleNames = node.modules ? node.modules.split(', ') : [];
                const primaryModule = moduleNames.length > 0 ? moduleNames[0] : 'base';
                const moduleInfo = moduleIcons[primaryModule] || {
                    icon: `/base/static/img/icons/default_module_icon.png`,
                    shortdesc: primaryModule
                };

                // Store module information for this model
                this.state.modelModules[node.id] = {
                    moduleName: primaryModule,
                    moduleIcon: moduleInfo.icon,
                    moduleDesc: moduleInfo.shortdesc
                };

                return {
                    id: node.id,
                    label: node.name,
                    model: node.model,
                    module: primaryModule,
                    moduleIcon: moduleInfo.icon,
                    moduleDesc: moduleInfo.shortdesc
                };
            });

            // Initially, filtered nodes are the same as all nodes
            this.state.filteredNodes = [...this.state.nodes];
        });

        onMounted(() => {
            if (this.containerRef.el) {
                // Initialize vis.js dataset objects
                this.graphNodes = new vis.DataSet([]);
                this.graphEdges = new vis.DataSet([]);

                // Initialize the network
                this.network = new vis.Network(
                    this.containerRef.el,
                    {
                        nodes: this.graphNodes,
                        edges: this.graphEdges
                    },
                    {
                        edges: {
                            arrows: 'to',
                            font: {
                                size: 10,
                                align: 'middle'
                            }
                        },
                        nodes: {
                            shape: 'image',
                            margin: 10,
                            font: {
                                size: 12,
                                face: 'Arial',
                                multi: 'html'
                            }
                        },
                        physics: {
                            stabilization: true,
                            barnesHut: {
                                gravitationalConstant: -2000,
                                springConstant: 0.04,
                                springLength: 200
                            }
                        }
                    }
                );

                // Set up network event handlers
                this.setupNetworkEvents();
            }
        });
    }

    /**
     * Set up event handlers for the vis.js network
     */
    setupNetworkEvents() {
        // Double-click to show model information
        this.network.on("doubleClick", (params) => {
            const modelId = params.nodes[0];
            if (modelId) {
                this.showModelInfo(modelId);
            }
        });

        // Right-click to remove a node from the graph
        this.network.on("oncontext", (params) => {
            params.event.preventDefault();
            params.event.stopPropagation();

            const nodeId = params.nodes[0];
            if (nodeId) {
                this.graphNodes.remove(nodeId);
                this.state.selectedModels.delete(nodeId);
            }
        });

        // Display field name on hover
        this.network.on("hoverEdge", (params) => {
            const edgeId = params.edge;
            const edge = this.graphEdges.get(edgeId);
            if (edge && edge.title) {
                // Show tooltip with field information
            }
        });
    }

    /**
     * Open the model form view
     * @param {number} modelId - The ID of the model to display
     */
    showModelInfo(modelId) {
        this.action.doAction({
            type: 'ir.actions.act_window',
            view_type: 'form',
            view_mode: 'form',
            views: [[false, 'form']],
            target: 'new',
            res_model: 'ir.model',
            res_id: modelId,
        });
    }

    /**
     * Toggle the display of module icons
     */
    toggleIcons() {
        this.state.showIcons = !this.state.showIcons;
        
        // Update all nodes with the new icon setting
        this.updateAllNodes();
    }

    /**
     * Update all nodes in the graph with current settings
     */
    updateAllNodes() {
        if (!this.graphNodes) return;
        
        const nodesToUpdate = [];
        this.graphNodes.forEach(node => {
            const originalNode = this.state.nodes.find(n => n.id === node.id);
            if (originalNode) {
                nodesToUpdate.push(this.createNodeObject(originalNode));
            }
        });
        
        if (nodesToUpdate.length > 0) {
            this.graphNodes.update(nodesToUpdate);
        }
    }

    /**
     * Create a node object with proper formatting for the graph
     * @param {Object} node - The node data
     * @returns {Object} - Formatted node object for vis.js
     */
    createNodeObject(node) {
        const moduleInfo = this.state.modelModules[node.id];
        const iconPath = moduleInfo ? moduleInfo.moduleIcon : `/base/static/img/icons/default_module_icon.png`;      
        return {
            id: node.id,
            label: node.label,
            image: iconPath,
            title: node.model,
            moduleInfo: moduleInfo
        };
    }

    /**
     * Handle filter input for model search
     * @param {Event} event - Input keyup event
     */
    onInputKeyup(event) {
        const filter = event.target.value.toUpperCase();

        // Filter nodes based on search input
        this.state.filteredNodes = this.state.nodes.filter(node =>
            node.model.toUpperCase().includes(filter) ||
            node.label.toUpperCase().includes(filter)
        );
    }

    /**
     * Change the maximum depth for relation traversal and refresh the graph
     * @param {Event} event - Change event from the depth selector
     */
    onChangeDepth(event) {
        this.state.maxDepth = parseInt(event.target.value);
        
        // Refresh all selected models with the new depth
        this.refreshGraphWithNewDepth();
    }
    
    /**
     * Refresh the entire graph with the new depth setting
     */
    async refreshGraphWithNewDepth() {
        // Clear current graph data
        this.graphNodes.clear();
        this.graphEdges.clear();
        
        // Store selected models in an array before clearing
        const selectedModels = Array.from(this.state.selectedModels).map(id => {
            const node = this.state.nodes.find(n => n.id === id);
            return node ? { id: node.id, label: node.label } : null;
        }).filter(Boolean);
        
        // Reset selected models
        this.state.selectedModels.clear();
        this.state.edges = [];
        
        // Re-add each previously selected model with the new depth
        for (const model of selectedModels) {
            // Add node back to graph
            const originalNode = this.state.nodes.find(n => n.id === model.id);
            if (originalNode) {
                this.graphNodes.update([this.createNodeObject(originalNode)]);
                this.state.selectedModels.add(model.id);
                
                // Fetch model relationships with the new depth
                await this.fetchAndUpdateModelRelations(model.id);
            }
        }
    }
    
    /**
     * Fetch and update model relations for a specific model ID
     * @param {number} modelId - The model ID to fetch relations for
     */
    async fetchAndUpdateModelRelations(modelId) {
        try {
            const data = await this.orm.call(
                'ir.model',
                'get_model_relation_graph',
                [modelId, this.state.maxDepth]
            );

            // Process and add nodes to the graph
            const nodes = [];
            data.nodes.forEach(node => {
                if (node.id && !this.state.selectedModels.has(node.id)) {
                    // Find full node info
                    const originalNode = this.state.nodes.find(n => n.id === node.id);
                    if (originalNode) {
                        nodes.push(this.createNodeObject(originalNode));
                        this.state.selectedModels.add(node.id);
                    }
                }
            });
            this.graphNodes.update(nodes);

            // Process and add edges to the graph
            const edges = [];
            data.edges.forEach(edge => {
                const existingEdge = this.state.edges.find(e =>
                    e.from === edge.from && e.to === edge.to
                );

                if (!existingEdge) {
                    const newEdge = {
                        id: `${edge.from}_${edge.to}_${edge.field}`, // Unique identifier for the edge
                        from: edge.from,
                        to: edge.to,
                        title: edge.field,
                        label: edge.field,
                        type: edge.type // Store the relation type
                    };

                    if (edge.type) {
                        newEdge.color = {
                            color: this.state.relationTypeColors[edge.type] || this.state.relationTypeColors.one2one,
                            highlight: this.state.relationTypeColors[edge.type] || this.state.relationTypeColors.one2one
                        };
                        newEdge.title = `${edge.field} (${edge.type})`;
                    }

                    this.state.edges.push(newEdge);
                    edges.push(newEdge);
                }
            });

            this.graphEdges.update(edges);
        } catch (error) {
            console.error("Error fetching model graph data:", error);
        }
    }

    /**
     * Handle clicking on a model in the navigation list
     * @param {Event} event - Click event
     */
    async onClickModel(event) {
        const modelId = parseInt(event.target.dataset.id);
        const originalNode = this.state.nodes.find(n => n.id === modelId);

        if (!modelId || this.state.selectedModels.has(modelId) || !originalNode) {
            return;
        }

        // Update the graph with the selected model
        this.graphNodes.update([this.createNodeObject(originalNode)]);
        this.state.selectedModels.add(modelId);

        // Fetch model relationships with depth limit
        await this.fetchAndUpdateModelRelations(modelId);
    }

    /**
     * Check if a model is selected in the graph
     * @param {number} modelId - Model ID to check
     * @returns {boolean} - True if the model is selected
     */
    isModelSelected(modelId) {
        return this.state.selectedModels.has(modelId);
    }
    
    /**
     * Handle color change for a relation type
     * @param {Event} event - Change event from the color input
     */
    onChangeRelationColor(event) {
        const relationType = event.target.dataset.relationType;
        const color = event.target.value;
        
        // Update the color in state
        this.state.relationTypeColors[relationType] = color;
        
        // Update all edges of this relation type in the graph
        if (this.graphEdges) {
            // Get all edges that match this relation type
            const edgesToUpdate = [];
            
            // Iterate through all edges in our state
            this.state.edges.forEach(edge => {
                if (edge.type === relationType) {
                    // Create an updated edge object
                    edgesToUpdate.push({
                        id: edge.id,
                        color: {
                            color: color,
                            highlight: color
                        }
                    });
                }
            });
            
            // Apply updates to the graph if we have edges to update
            if (edgesToUpdate.length > 0) {
                this.graphEdges.update(edgesToUpdate);
            }
        }
    }
}

// Register this component as a client action
registry.category("actions").add("model_graph", GraphModelComponent);

export default GraphModelComponent;