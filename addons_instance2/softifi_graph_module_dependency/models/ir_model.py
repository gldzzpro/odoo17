from odoo import models, api
from .graph_builder import GraphBuilderMixin


class IrModel(models.Model):
    _name = 'ir.model'
    _inherit = ["ir.model", "graph.builder.mixin"]

    def get_model_relation_graph(
        self, max_depth=2, current_depth=0, visited_models=None
    ):
        """
        Generate a graph representation of model relations based on foreign keys.
        Returns a dictionary with nodes and edges similar to module dependency graph.

        Parameters:
            max_depth (int): Maximum recursion depth to prevent infinite loops
            current_depth (int): Current recursion depth (used internally)
            visited_models (set): Set of already visited model IDs to prevent cycles

        Returns:
            dict: Dictionary with 'nodes' and 'edges' lists representing the graph
        """
        # Initialize options dictionary for graph builder
        options = {
            "max_depth": max_depth,
            "current_depth": current_depth,
            "all_visited": visited_models or set(),
        }
        
        # Use the shared graph builder core
        return self._build_graph_core(
            record_ids=self.ids,
            options=options,
            get_relations=self._get_model_relations,
            get_exclusions=None,  # No exclusions for model relations
            create_node=self._create_model_node,
            create_relation_edge=self._create_model_relation_edge,
            create_exclusion_edge=None,  # No exclusions for model relations
        )
    
    def _get_model_relations(self, model):
        """Get related models through relational fields."""
        related_models = []
        
        # Get all fields of this model that are relational
        relational_fields = self.env["ir.model.fields"].search(
            [
                ("model_id", "=", model.id),
                ("ttype", "in", ["many2one", "one2many", "many2many"]),
            ]
        )
        
        # Find target models for each relational field
        for field in relational_fields:
            if field.relation:
                target_model = self.env["ir.model"].search(
                    [("model", "=", field.relation)], limit=1
                )
                if target_model:
                    # Store the field information with the target model for edge creation
                    target_model.field_info = {
                        "name": field.name,
                        "type": field.ttype
                    }
                    related_models.append(target_model)
        
        return related_models
    
    def _create_model_node(self, model, options):
        """Create a node dictionary for a model record."""
        return {
            "id": model.id,
            "label": model.name,
            "model": model.model,
            "depth": options.get("current_depth", 0),
        }
    
    def _create_model_relation_edge(self, source_model, target_model):
        """Create an edge dictionary for a model relation."""
        field_info = getattr(target_model, 'field_info', {})
        return {
            "from": source_model.id,
            "to": target_model.id,
            "field": field_info.get("name", ""),
            "type": field_info.get("type", ""),
        }
    
    def _create_node_data(self, record, options):
        """Override from graph.builder.mixin to use model-specific node creation."""
        return self._create_model_node(record, options)
