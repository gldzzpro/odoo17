/** @odoo-module */
import { Component, useState, useRef, onWillStart, onMounted } from "@odoo/owl";
import { useService } from "@web/core/utils/hooks";
import { registry } from "@web/core/registry";
import { loadJS, loadCSS } from "@web/core/assets";

const DEFAULT_MODULE_ICON = `/base/static/img/icons/default_module_icon.png`;

const DEFAULT_STATE_COLOR = {
  uninstallable: "#eaeaa4",
  installed: "#97c2fc",
  uninstalled: "#e5f8fc",
  "to install": "#939afc",
  "to upgrade": "#AEFCAB",
  "to remove": "#fcadb7",
};

const DEFAULT_NETWORK_OPTIONS = {
  edges: {
    arrows: "to",
  },
  nodes: {
    margin: 10,
    shape: "image",
    size: 20,
    font: {
      size: 12,
      face: "Arial",
      multi: "html",
    },
  },
};

export class GraphModuleComponent extends Component {
  static template = "module_graphe_template";

  static props = {};

  setup() {
    this.state = useState({
      nodes: [],
      edges: [],
      module_info: {},
      selectedModules: new Set(),
      stateFilter: {},
      searchValue: "",
      maxDepth: 0,
      limitDepthEnabled: false,
      stopOnInstalled: false,
      stopOnCategory: null,
      stopOnNonCustom: false,
      customFilter: null,
      graph: null,
      loading: false,
      // Available states and categories with counts
      availableStates: new Map(),
      availableCategories: new Map(),
      // Selected states and categories
      selectedStates: [],
      selectedCategories: [],
      // Filter modes (include = true, exclude = false)
      stateFilterMode: true, // Default is "is one of" (include)
      categoryFilterMode: true, // Default is "is one of" (include)
      // Application filter: null = all, true = only apps, false = non-apps
      applicationFilter: null,
      moduleTypeFilter: null,
      // Combined domain for filtering
      domain: [],
      // UI states for dropdowns
      stateDropdownOpen: false,
      categoryDropdownOpen: false,
      // Dependency direction: 'depends_on' or 'depended_by'
      direction: "depends_on",
    });
    this.graphNodes = null;
    this.graphEdges = null;
    this.network = null;
    this.containerRef = useRef("graph");
    this.dropdownStateRef = useRef("dropdownState");
    this.dropdownCategoryRef = useRef("dropdownCategory");
    this.orm = useService("orm");
    this.action = useService("action");

    onWillStart(async () => {
      // Load vis.js library
      await loadJS(
        "https://cdnjs.cloudflare.com/ajax/libs/vis/4.21.0/vis.min.js"
      );
      await loadCSS(
        "https://cdnjs.cloudflare.com/ajax/libs/vis/4.21.0/vis.min.css"
      );

      // Fetch module data
      const data = await this.orm.call("ir.module.module", "search_read", [], {
        fields: [
          "id",
          "name",
          "shortdesc",
          "state",
          "icon",
          "category_id",
          "application",
          "module_type",
        ],
        order: "shortdesc",
      });

      // Process module data
      this.state.nodes = data.map((node) => ({
        ...node,
        label: `${node.name} - ${node.id}`,
        icon: node.icon || DEFAULT_MODULE_ICON,
        color: DEFAULT_STATE_COLOR[node.state],
      }));
      const stateSet = new Set(this.state.nodes.map((node) => node.state));
      this.state.stateFilter = Object.fromEntries(
        Array.from(stateSet).map((state) => [state, true])
      );
      // Extract unique states with counts
      const stateMap = new Map();
      // Extract unique categories with counts
      const categoryMap = new Map();

      for (const module of this.state.nodes) {
        // Process states
        const state = module.state;
        if (stateMap.has(state)) {
          stateMap.set(state, stateMap.get(state) + 1);
        } else {
          stateMap.set(state, 1);
        }

        // Process categories
        if (module.category_id && module.category_id.length === 2) {
          const [categoryId, categoryName] = module.category_id;
          if (categoryMap.has(categoryId)) {
            categoryMap.set(categoryId, {
              name: categoryName,
              count: categoryMap.get(categoryId).count + 1,
            });
          } else {
            categoryMap.set(categoryId, {
              name: categoryName,
              count: 1,
            });
          }
        }
      }

      this.state.availableStates = stateMap;
      this.state.availableCategories = categoryMap;
    });

    onMounted(() => {
      if (this.containerRef.el) {
        // Initialize vis.js dataset objects
        this.graphNodes = new vis.DataSet([]);
        this.graphEdges = new vis.DataSet([]);
        // Initialize the network with custom node rendering
        this.network = new vis.Network(
          this.containerRef.el,
          {
            nodes: this.graphNodes,
            edges: this.graphEdges,
          },
          DEFAULT_NETWORK_OPTIONS
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
    // Double-click to show module information
    this.network.on("doubleClick", (params) => {
      const moduleId = params.nodes[0];
      if (moduleId) {
        this.showModuleInfo(moduleId);
      }
    });

    // Right-click to remove a node from the graph
    this.network.on("oncontext", (params) => {
      params.event.preventDefault();
      params.event.stopPropagation();

      const nodeId = params.nodes[0];
      if (nodeId) {
        this.graphNodes.remove(nodeId);
        this.state.selectedModules.delete(nodeId);
      }
    });
  }
  /**
   * Create a node object with proper formatting for the graph
   * @param {Object} node - The node data
   * @returns {Object} - Formatted node object for vis.js
   */
  createNodeObject(dataNode) {
    const node = this.state.nodes.find((node) => node.id === dataNode.id);
    if (!node) {
      return;
    }
    const iconPath = node.icon || DEFAULT_MODULE_ICON;
    return {
      id: node.id,
      label: node.label,
      color: {
        background: dataNode.in_cycle
          ? "red"
          : node.color || DEFAULT_STATE_COLOR[node.state],
        highlight: dataNode.in_cycle
          ? "red"
          : node.color || DEFAULT_STATE_COLOR[node.state],
        hover: dataNode.in_cycle
          ? "red"
          : node.color || DEFAULT_STATE_COLOR[node.state],
      },
      state: node.state,
      image: iconPath,
      shapeProperties: {
        useBorderWithImage: true,
        interpolation: true,
        coordinateOrigin: "center",
        borderRadius: 10,
      },
      title: node.shortdesc,
    };
  }
  /**
   * Open the module form view
   * @param {number} moduleId - The ID of the module to display
   */
  showModuleInfo(moduleId) {
    this.action.doAction({
      type: "ir.actions.act_window",
      view_type: "form",
      view_mode: "form",
      views: [[false, "form"]],
      target: "new",
      res_model: "ir.module.module",
      res_id: moduleId,
    });
  }
  onInputKeyup(event) {
    this.state.searchValue = event.target.value;
    console.log(this.state.selectedModules);
  }

  onToggleState(event) {
    const stateKey = event.target.dataset.state;
    // Replace the stateFilter object with a new one
    this.state.stateFilter = {
      ...this.state.stateFilter,
      [stateKey]: !this.state.stateFilter[stateKey],
    };
  }
  // Toggle dropdown visibility
  toggleDropdown(type) {
    if (type === "state") {
      this.state.stateDropdownOpen = !this.state.stateDropdownOpen;
      if (this.state.stateDropdownOpen) {
        this.state.categoryDropdownOpen = false;
      }
    } else if (type === "category") {
      this.state.categoryDropdownOpen = !this.state.categoryDropdownOpen;
      if (this.state.categoryDropdownOpen) {
        this.state.stateDropdownOpen = false;
      }
    }
  }

  // Toggle filter mode (include/exclude)
  toggleFilterMode(type) {
    if (type === "state") {
      this.state.stateFilterMode = !this.state.stateFilterMode;
    } else if (type === "category") {
      this.state.categoryFilterMode = !this.state.categoryFilterMode;
    }
    this.updateDomain();
  }
  // Set application filter
  setApplicationFilter(value) {
    // value can be: null (all), true (only apps), false (non-apps)
    this.state.applicationFilter = value;
    this.updateDomain();
  }
  // Set application filter
  setModuleTypeFilter(value) {
    // value can be: null (all), true (only apps), false (non-apps)
    this.state.moduleTypeFilter = value;
    this.updateDomain();
  }

  // Toggle selection for a filter item
  toggleSelection(type, value) {
    let targetArray;
    if (type === "state") {
      targetArray = this.state.selectedStates;
    } else if (type === "category") {
      targetArray = this.state.selectedCategories;
    }

    const index = targetArray.indexOf(value);
    if (index > -1) {
      targetArray.splice(index, 1);
    } else {
      targetArray.push(value);
    }

    this.updateDomain();
  }

  // Clear all selections for a filter type
  clearSelections(type) {
    if (type === "state") {
      this.state.selectedStates = [];
    } else if (type === "category") {
      this.state.selectedCategories = [];
    }

    this.updateDomain();
  }

  // Get the operator based on filter mode
  getOperator(isIncludeMode) {
    return isIncludeMode ? "in" : "not in";
  }

  // Count modules that match the application filter
  getApplicationFilterCount(filterValue) {
    if (filterValue === null) {
      return this.state.nodes.length;
    }
    return this.state.nodes.filter(
      (module) => module.application === filterValue
    ).length;
  }
  getModuleTypeFilterCount(filterValue) {
    if (filterValue === null) {
      return this.state.nodes.length;
    }
    return this.state.nodes.filter(
      (module) => module.module_type === filterValue
    ).length;
  }

  // Update domain based on selected filters
  updateDomain() {
    const domain = [];

    // Add state conditions if any selected
    if (this.state.selectedStates.length > 0) {
      const operator = this.getOperator(this.state.stateFilterMode);
      domain.push(["state", operator, this.state.selectedStates]);
    }

    // Add category conditions if any selected
    if (this.state.selectedCategories.length > 0) {
      const operator = this.getOperator(this.state.categoryFilterMode);
      domain.push(["category_id", operator, this.state.selectedCategories]);
    }

    // Add application filter if set
    if (this.state.applicationFilter !== null) {
      domain.push(["application", "=", this.state.applicationFilter]);
    }

    //add module_type filter if set
    if (this.state.moduleTypeFilter !== null) {
      domain.push(["module_type", "=", this.state.moduleTypeFilter]);
    }

    this.state.domain = domain;
  }
  // String representation of the domain for debugging
  stringifyDomain() {
    return JSON.stringify(this.state.domain);
  }
  // Close dropdowns when clicking outside
  onClickOutside(ev) {
    const stateDropdown = this.dropdownStateRef.el;
    const categoryDropdown = this.dropdownCategoryRef.el;

    if (stateDropdown && !stateDropdown.contains(ev.target)) {
      this.state.stateDropdownOpen = false;
    }

    if (categoryDropdown && !categoryDropdown.contains(ev.target)) {
      this.state.categoryDropdownOpen = false;
    }
  }
  // A getter that always computes the filtered list from the full nodes array:
  get filteredNodes() {
    const search = this.state.searchValue.toUpperCase();
    const filteredNodes = this.state.nodes.filter((node) => {
      const matchesSearch =
        node.label.toUpperCase().includes(search) ||
        node.shortdesc.toUpperCase().includes(search);
      const matchesState = this.state.stateFilter[node.state];
      return matchesSearch && matchesState;
    });
    return filteredNodes;
  }

  /**
   * Build graph options object with dynamic domains
   */
  buildGraphOptions() {
    const options = {};
    const excludeDomains = [];

    // Set max depth if enabled
    if (this.state.limitDepthEnabled) {
      options.max_depth = this.state.maxDepth;
    }

    // Add the domains to options if we have any
    if (this.state.domain.length > 0) {
      options.stop_domains = [this.state.domain];
    }
    if (excludeDomains.length > 0) {
      options.exclude_domains = excludeDomains;
    }

    // Configure dependency/exclusion inclusion
    options.include_dependencies = this.state.includeDependencies !== false;
    options.include_exclusions = this.state.includeExclusions !== false;

    return options;
  }
  /**
   * Handle clicking on a module in the navigation list
   * @param {Event} event - Click event
   */
  async onClickModule(event) {
    const moduleId = parseInt(event.target.dataset.id);
    const moduleNode = this.state.nodes.find((n) => n.id === moduleId);

    if (!moduleId || this.state.selectedModules.has(moduleId) || !moduleNode) {
      return;
    }

    // Update the graph with the selected module
    this.graphNodes.update([this.createNodeObject(moduleNode)]);

    this.state.loading = true;

    // Fetch module dependencies
    try {
      // Build options object with stop conditions
      const options = this.buildGraphOptions();

      const moduleIds = [...Array.from(this.state.selectedModules), moduleId];

      // Determine which backend method to call based on direction
      const method =
        this.state.direction === "depends_on"
          ? "get_module_graph"
          : "get_reverse_dependency_graph";

      // Call the server method with the options
      const data = await this.orm.call(
        "ir.module.module",
        method,
        [moduleIds],
        { options }
      );
      console.log({ data });

      this.graphNodes.update(
        data.nodes.map((node) => this.createNodeObject(node))
      );

      const edges = [];
      const graphEdges = Object.values(this.graphEdges._data);

      data.edges.forEach((edge) => {
        const existingEdge = graphEdges.find(
          (e) => e.from == edge.from && e.to == edge.to
        );

        if (!existingEdge) {
          const newEdge = {
            from: edge.from,
            to: edge.to,
          };

          if (edge.type === "cycleDirection") {
            newEdge.color = {
              color: "red",
              highlight: "red",
            };
          }

          this.state.edges.push(newEdge);
          edges.push(newEdge);
        }
      });
      this.graphEdges.update(edges);
      this.state.selectedModules.add(moduleId);
    } catch (error) {
      console.error("Error fetching module graph data:", error);
    } finally {
      this.state.loading = false;
    }
  }

  /**
   * Updates max depth setting
   * @param {Event} event Change event from input
   */
  onChangeMaxDepth(event) {
    this.state.maxDepth = parseInt(event.target.value, 10) || 0;
  }

  /**
   * Set dependency direction and clear graph
   * @param {'depends_on'|'depended_by'} direction
   */
  setDirection(direction) {
    if (this.state.direction !== direction) {
      this.state.direction = direction;
      this.onClearGraph();
    }
  }
  /**
   * Toggles stop on installed flag
   */
  toggleStopOnInstalled() {
    this.state.stopOnInstalled = !this.state.stopOnInstalled;
  }

  /**
   * Sets category stop condition
   * @param {Object} category Category to stop on
   */
  setStopCategory(category) {
    this.state.stopOnCategory = category.id;
  }

  /**
   * Clears all stop conditions
   */
  clearStopConditions() {
    this.state.maxDepth = 0;
    this.state.stopOnInstalled = false;
    this.state.stopOnCategory = null;
    this.state.stopOnNonCustom = false;
    this.state.customFilter = null;
    this.clearSelections("state");
    this.clearSelections("category");
    this.state.applicationFilter = null;
    this.state.domain = [];
  }

  /**
   * Sets a custom domain filter
   * @param {Array} domain Odoo domain filter
   */
  setCustomFilter(domain) {
    this.state.customFilter = domain;
  }

  /**
   * Check if a module is selected in the graph
   * @param {number} moduleId - Module ID to check
   * @returns {boolean} - True if the module is selected
   */
  isModuleSelected(moduleId) {
    return this.state.selectedModules.has(moduleId);
  }

  /**
   * Checks if a module is in the graph
   * @param {number} moduleId - Module ID to check
   * @returns {boolean} - True if the module is in the graph
   */
  isModuleInGraph(moduleId) {
    return this.graphNodes?._data
      ? Object.keys(this.graphNodes._data).some((nodeId) => nodeId == moduleId)
      : false;
  }
  /**
   * Handle color change for a module
   * @param {Event} event - Change event from the color input
   */
  onChangeColor(event) {
    const color = event.target.value;
    const moduleId = event.target.dataset.id;
    const originalNodeIndex = this.state.nodes.findIndex(
      (node) => node.id == moduleId
    );
    this.state.nodes[originalNodeIndex].color = color;
    this.graphNodes.update([this.state.nodes[originalNodeIndex]]);
  }

  onClearGraph() {
    this.graphEdges.clear();
    this.graphNodes.clear();
    this.state.selectedModules = new Set();
    this.state.edges = [];
  }

  /**
   * List of selected module objects for chips display
   */
  get selectedModuleObjects() {
    return Array.from(this.state.selectedModules)
      .map((id) => this.state.nodes.find((node) => node.id === id))
      .filter(Boolean);
  }

  /**
   * Remove a module from selected modules and graph
   */
  removeSelectedModule(moduleId) {
    this.state.selectedModules.delete(moduleId);
    if (this.graphNodes && this.graphNodes._data[moduleId]) {
      this.graphNodes.remove(moduleId);
    }
    // Optionally remove related edges
    if (this.graphEdges) {
      const edgesToRemove = Object.values(this.graphEdges._data)
        .filter((e) => e.from == moduleId || e.to == moduleId)
        .map((e) => e.id);
      this.graphEdges.remove(edgesToRemove);
    }
  }
}

// Register this component as a client action
registry.category("actions").add("module_graph", GraphModuleComponent);

export default GraphModuleComponent;
