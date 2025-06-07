# -*- coding: utf-8 -*-
from odoo import models, api
import logging
import re
from typing import List, Dict, Any, Optional, Union, Tuple

_logger = logging.getLogger(__name__)

class ModuleCategoryHelper:
    """Helper class for category-related module operations.
    
    This class provides methods to find modules based on category patterns,
    supporting both whitelist and blacklist filtering with pattern matching.
    """
    
    def __init__(self, env):
        self.env = env
    
    def get_modules_by_category_prefixes(self, category_prefixes, options=None):
        """Find modules matching any of the given category prefixes.
        
        Args:
            category_prefixes: List of category prefixes to match (e.g. ['custom/hr', 'custom-hr'])
            options: Optional dictionary with additional filtering options
                - exact_match: If True, only match exact category names, not prefixes
                - include_subcategories: If True, include modules from subcategories
                - whitelist: List of patterns to include
                - blacklist: List of patterns to exclude
                - include_missing: Boolean indicating whether to include modules with no category
            
        Returns:
            Recordset of ir.module.module records matching the category prefixes
        """
        
        _logger.debug(
            "Getting modules by category prefixes: %s, options: %s",
            category_prefixes, options
        )
        if not category_prefixes and not options:
            return self.env['ir.module.module'].browse([])
            
        options = options or {}
        
        # Check if we're using the new whitelist/blacklist approach
        if any(key in options for key in ['whitelist', 'blacklist', 'include_missing']):
            return self._get_modules_by_patterns(options)
        
        # Otherwise, use the original prefix-based approach
        exact_match = options.get('exact_match', False)
        include_subcategories = options.get('include_subcategories', True)
        
        # Build domain for category search
        domain = self._build_category_prefix_domain(category_prefixes, exact_match)
        
        # Get matching categories
        categories = self.env['ir.module.category'].search(domain)
        
        # If including subcategories, find all child categories
        if include_subcategories and categories:
            child_categories = self._get_all_child_categories(categories)
            categories |= child_categories
        
        # Find modules in matching categories
        if categories:
            return self.env['ir.module.module'].search([('category_id', 'in', categories.ids)])
        return self.env['ir.module.module'].browse([])
    
    def _build_category_prefix_domain(self, category_prefixes: List[str], exact_match: bool = False) -> List:
        """Build an Odoo domain for searching categories by prefixes.
        
        Args:
            category_prefixes: List of category prefixes to match
            exact_match: If True, only match exact category names, not prefixes
            
        Returns:
            List representing an Odoo domain expression
        """
        if not category_prefixes:
            return [('id', '=', False)]  # Empty domain that matches nothing
            
        # Normalize prefixes to handle different formats (custom/hr, custom-hr)
        normalized_prefixes = []
        for prefix in category_prefixes:
            # Add original prefix
            normalized_prefixes.append(prefix)
            
            # Add variations with different separators
            if '/' in prefix:
                normalized_prefixes.append(prefix.replace('/', '-'))
            if '-' in prefix:
                normalized_prefixes.append(prefix.replace('-', '/'))
        
        # Build domain
        domain = []
        operator = '=' if exact_match else '=like'
        
        for i, prefix in enumerate(normalized_prefixes):
            if exact_match:
                domain_part = [('name', operator, prefix)]
            else:
                domain_part = [('name', operator, prefix + '%')]
                
            if i == 0:
                domain = domain_part
            else:
                domain = ['|'] + domain_part + domain
                
        return domain
    
    def _get_modules_by_patterns(self, options: Dict[str, Any]):
        """Find modules based on whitelist/blacklist patterns and missing category option.
        
        Args:
            options: Dictionary with filtering options
                - whitelist: List of patterns (plain substrings or regex) to include
                - blacklist: List of patterns to exclude
                - include_missing: Boolean indicating whether to include modules with no category
                - include_subcategories: If True, include modules from subcategories
            
        Returns:
            Recordset of ir.module.module records matching the criteria
        """
        # Get category domain based on whitelist/blacklist
        category_domain = self._build_category_pattern_domain(options)
        
        # Get matching categories
        categories = self.env['ir.module.category'].search(category_domain)
        
        # If including subcategories, find all child categories
        if options.get('include_subcategories', True) and categories:
            child_categories = self._get_all_child_categories(categories)
            categories |= child_categories
        
        # Build module domain
        module_domain = []
        
        # Add category filter
        if categories:
            module_domain = [('category_id', 'in', categories.ids)]
        
        # Add missing category filter if requested
        if options.get('include_missing', False):
            if module_domain:
                module_domain = ['|', ('category_id', '=', False)] + module_domain
            else:
                module_domain = [('category_id', '=', False)]
        elif not categories:
            # If no categories matched and we're not including missing, return empty set
            return self.env['ir.module.module'].browse([])
        
        # Find modules matching the domain
        return self.env['ir.module.module'].search(module_domain)
    
    def _build_category_pattern_domain(self, options: Dict[str, Any]) -> List:
        """Build an Odoo domain for searching categories based on whitelist/blacklist patterns.
        
        Args:
            options: Dictionary with filtering options
                - whitelist: List of patterns to include
                - blacklist: List of patterns to exclude
            
        Returns:
            List representing an Odoo domain expression
        """
        domain = []
        
        # Process whitelist patterns
        whitelist = options.get('whitelist', [])
        if whitelist:
            whitelist_domain = []
            for i, pattern in enumerate(whitelist):
                if i == 0:
                    whitelist_domain = [('name', 'ilike', pattern)]
                else:
                    whitelist_domain = ['|', ('name', 'ilike', pattern)] + whitelist_domain
            domain = whitelist_domain
        
        # Process blacklist patterns
        blacklist = options.get('blacklist', [])
        for pattern in blacklist:
            domain = [('name', 'not ilike', pattern)] + domain
        
        return domain if domain else [('id', '!=', False)]  # Default to match all if no patterns
    
    def _get_all_child_categories(self, parent_categories):
        """Recursively get all child categories of the given parent categories.
        
        Args:
            parent_categories: Recordset of ir.module.category records
            
        Returns:
            Recordset of all child categories
        """
        all_children = self.env['ir.module.category'].browse([])
        for category in parent_categories:
            direct_children = category.child_ids
            if direct_children:
                all_children |= direct_children
                all_children |= self._get_all_child_categories(direct_children)
        return all_children