# -*- coding: utf-8 -*-
# from odoo import http


# class ModuleCustomB(http.Controller):
#     @http.route('/module_custom_b/module_custom_b', auth='public')
#     def index(self, **kw):
#         return "Hello, world"

#     @http.route('/module_custom_b/module_custom_b/objects', auth='public')
#     def list(self, **kw):
#         return http.request.render('module_custom_b.listing', {
#             'root': '/module_custom_b/module_custom_b',
#             'objects': http.request.env['module_custom_b.module_custom_b'].search([]),
#         })

#     @http.route('/module_custom_b/module_custom_b/objects/<model("module_custom_b.module_custom_b"):obj>', auth='public')
#     def object(self, obj, **kw):
#         return http.request.render('module_custom_b.object', {
#             'object': obj
#         })

