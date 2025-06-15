# -*- coding: utf-8 -*-
import json
from odoo import http
from odoo.http import request
import logging

_logger = logging.getLogger(__name__)

class ModuleGraphController(http.Controller):

    @http.route('/graph_module_dependency/module_graph', type='json', auth='public', methods=['POST'], csrf=False)
    def get_module_graph_route(self, module_ids, options=None):
        """
        Public route to get the dependency graph for given module IDs.
        :param list module_ids: List of integers representing module IDs.
        :param dict options: Optional dictionary for graph building options.
        :return: JSON representation of the module graph.
        """
        try:
            # Ensure module_ids is a list of integers
            if not isinstance(module_ids, list) or not all(isinstance(mid, int) for mid in module_ids):
                return {'error': 'Invalid input: module_ids must be a list of integers.'}

            options = options or {}
            graph_data = request.env['ir.module.module'].get_module_graph(module_ids, options=options)
            return graph_data
        except Exception as e:
            _logger.error("Error fetching module graph: %s", e, exc_info=True)
            return {'error': 'An error occurred while generating the module graph.'}

    @http.route('/graph_module_dependency/reverse_module_graph', type='json', auth='public', methods=['POST'], csrf=False)
    def get_reverse_dependency_graph_route(self, module_ids, options=None):
        """
        Public route to get the reverse dependency graph for given module IDs.
        :param list module_ids: List of integers representing module IDs.
        :param dict options: Optional dictionary for graph building options.
        :return: JSON representation of the reverse module graph.
        """
        try:
            # Ensure module_ids is a list of integers
            if not isinstance(module_ids, list) or not all(isinstance(mid, int) for mid in module_ids):
                return {'error': 'Invalid input: module_ids must be a list of integers.'}

            options = options or {}
            graph_data = request.env['ir.module.module'].get_reverse_dependency_graph(module_ids, options=options)
            return graph_data
        except Exception as e:
            _logger.error("Error fetching reverse dependency graph: %s", e, exc_info=True)
            return {'error': 'An error occurred while generating the reverse dependency graph.'}
            
    @http.route('/graph_module_dependency/category_module_graph', type='json', auth='public', methods=['POST'], csrf=False)
    def get_category_module_graph_route(self, category_prefixes, options=None):
        """
        Public route to get the dependency graph for modules matching category prefixes.
        :param list category_prefixes: List of strings representing category prefixes to match.
        :param dict options: Optional dictionary for graph building options.
            - exact_match: If True, only match exact category names, not prefixes
            - include_subcategories: If True, include modules from subcategories
            - max_depth: Maximum depth to traverse in the graph
            - stop_domains: List of domains to stop traversal
            - exclude_domains: List of domains to exclude modules
        :return: JSON representation of the module graph.
        """
        try:
            # Ensure category_prefixes is a list of strings
            if not isinstance(category_prefixes, list) or not all(isinstance(prefix, str) for prefix in category_prefixes):
                return {'error': 'Invalid input: category_prefixes must be a list of strings.'}

            options = options or {}
            graph_data = request.env['ir.module.module'].get_category_module_graph(category_prefixes, options=options)
            return graph_data
        except Exception as e:
            _logger.error("Error fetching category module graph: %s", e, exc_info=True)
            return {'error': 'An error occurred while generating the category module graph.'}

    @http.route('/graph_module_dependency/reverse_category_module_graph', type='json', auth='public', methods=['POST'], csrf=False)
    def get_reverse_category_module_graph_route(self, category_prefixes, options=None):
        """
        Public route to get the reverse dependency graph for modules matching category prefixes.
        :param list category_prefixes: List of strings representing category prefixes to match.
        :param dict options: Optional dictionary for graph building options.
            - exact_match: If True, only match exact category names, not prefixes
            - include_subcategories: If True, include modules from subcategories
            - max_depth: Maximum depth to traverse in the graph
            - stop_domains: List of domains to stop traversal
            - exclude_domains: List of domains to exclude modules
        :return: JSON representation of the reverse module graph.
        """
        try:
            # Ensure category_prefixes is a list of strings
            if not isinstance(category_prefixes, list) or not all(isinstance(prefix, str) for prefix in category_prefixes):
                return {'error': 'Invalid input: category_prefixes must be a list of strings.'}

            options = options or {}
            graph_data = request.env['ir.module.module'].get_reverse_category_module_graph(category_prefixes, options=options)
            return graph_data
        except Exception as e:
            _logger.error("Error fetching reverse category module graph: %s", e, exc_info=True)
            return {'error': 'An error occurred while generating the reverse category module graph.'}
