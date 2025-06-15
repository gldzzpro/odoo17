from odoo import models, api
import logging

_logger = logging.getLogger(__name__)


class GraphBuilderMixin(models.AbstractModel):
    """Mixin providing common graph building functionality for both module and model graphs."""
    _name = "graph.builder.mixin"
    _description = "Graph Builder Mixin"

    @api.model
    def _build_graph_core(
        self,
        record_ids,
        options,
        get_relations,
        get_exclusions,
        create_node,
        create_relation_edge,
        create_exclusion_edge,
        should_stop_traversal=None,
        check_exclusion=None,
    ):
        """
        Core graph builder with configurable traversal logic.
        
        This function handles the common graph building functionality:
        - Record traversal
        - Cycle detection
        - Depth tracking
        - Node/edge creation and deduplication
        
        Args:
            record_ids: List of record IDs to start the graph from
            options: Dictionary of options controlling graph behavior
            get_relations: Function that returns related records for a given record
            get_exclusions: Function that returns exclusion records for a given record
            create_node: Function that creates a node dictionary for a record
            create_relation_edge: Function that creates an edge dictionary for a relation
            create_exclusion_edge: Function that creates an edge dictionary for an exclusion
            should_stop_traversal: Optional function to determine if traversal should stop
            check_exclusion: Optional function to check if a record should be excluded
            
        Returns:
            dict: Dictionary with 'nodes' and 'edges' lists representing the graph
        """
        options = dict(options or {})
        if "current_depth" not in options:
            options["current_depth"] = 0
        if "cycle_counter" not in options:
            options.update(
                {
                    "cycle_counter": 0,
                    "all_visited": set(),
                    "current_path": [],
                    "cycles": {},
                }
            )

        record_ids = record_ids if isinstance(record_ids, list) else [record_ids]
        if not record_ids or (
            options.get("max_depth", False)
            and options["current_depth"] > options["max_depth"]
        ):
            return {"nodes": [], "edges": []}

        records = self.browse(record_ids)
        nodes, edges = [], []

        for record in records:
            # Cycle detection
            if record.id in options["current_path"]:
                cycle_start = options["current_path"].index(record.id)
                cycle_nodes = options["current_path"][cycle_start:] + [record.id]
                options["cycle_counter"] += 1
                options["cycles"][options["cycle_counter"]] = set(cycle_nodes)
                continue

            options["current_path"].append(record.id)
            options["all_visited"].add(record.id)

            # Node creation
            node_data = create_node(record, options)
            nodes.append(node_data)

            # Check if we should stop traversal for this record
            if should_stop_traversal and should_stop_traversal(record, options):
                options["current_path"].pop()
                continue

            next_options = dict(options, current_depth=options["current_depth"] + 1)

            # Process relations
            if options.get("include_relations", True):
                self._process_graph_relations(
                    record,
                    get_relations,
                    create_relation_edge,
                    next_options,
                    edges,
                    nodes,
                    get_relations,
                    get_exclusions,
                    create_relation_edge,
                    create_exclusion_edge,
                    check_exclusion,
                )

            # Process exclusions
            if options.get("include_exclusions", True) and get_exclusions:
                self._process_graph_relations(
                    record,
                    get_exclusions,
                    create_exclusion_edge,
                    next_options,
                    edges,
                    nodes,
                    get_relations,
                    get_exclusions,
                    create_relation_edge,
                    create_exclusion_edge,
                    check_exclusion,
                )

            options["current_path"].pop()

        # Final processing
        if options["current_depth"] == 0 and options.get("cycles"):
            self._mark_cycles_in_graph(nodes, edges, options["cycles"])

        return {
            "nodes": list({n["id"]: n for n in nodes}.values()),
            "edges": list({f"{e['from']}-{e['to']}": e for e in edges}.values()),
        }

    def _process_graph_relations(
        self,
        record,
        get_relations,
        create_edge,
        next_options,
        edges,
        nodes,
        get_all_relations,
        get_all_exclusions,
        create_relation_edge,
        create_exclusion_edge,
        check_exclusion=None,
    ):
        """Helper to process relations/exclusions for graph building."""
        relations = []
        for rel in get_relations(record):
            if check_exclusion and check_exclusion(rel, next_options):
                continue
            relations.append(rel.id)
            edges.append(create_edge(record, rel))

        if relations:
            res = self._build_graph_core(
                relations,
                next_options,
                get_all_relations,
                get_all_exclusions,
                lambda r, o: self._create_node_data(r, o),  # Use the record's create_node function
                create_relation_edge,
                create_exclusion_edge,
                lambda r, o: self._should_stop_graph_traversal(r, o) if hasattr(self, '_should_stop_graph_traversal') else None,
                check_exclusion,
            )
            nodes.extend(res["nodes"])
            edges.extend(res["edges"])
        return relations

    def _mark_cycles_in_graph(self, nodes, edges, cycles):
        """Mark all nodes and edges that are part of cycles."""
        # Process nodes
        for node in nodes:
            for cycle_id, cycle_nodes in cycles.items():
                if node["id"] in cycle_nodes:
                    node["in_cycle"] = True
                    node["cycle_id"] = cycle_id
                    node["type"] = "cycleNode"

        # Process edges
        for edge in edges:
            for cycle_id, cycle_nodes in cycles.items():
                # Check if both ends of the edge are in the same cycle
                if edge["from"] in cycle_nodes and edge["to"] in cycle_nodes:
                    edge["in_cycle"] = True
                    edge["cycle_id"] = cycle_id
                    edge["type"] = "cycleDirection"

        return nodes, edges

    def _create_node_data(self, record, options):
        """Default implementation for creating node data.
        Should be overridden by specific models."""
        return {
            "id": record.id,
            "label": record.name if hasattr(record, 'name') else str(record.id),
            "depth": options.get("current_depth", 0),
        }