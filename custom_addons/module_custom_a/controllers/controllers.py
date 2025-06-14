# -*- coding: utf-8 -*-
# from odoo import http


# class ModuleCustomA(http.Controller):
#     @http.route('/module_custom_a/module_custom_a', auth='public')
#     def index(self, **kw):
#         return "Hello, world"

#     @http.route('/module_custom_a/module_custom_a/objects', auth='public')
#     def list(self, **kw):
#         return http.request.render('module_custom_a.listing', {
#             'root': '/module_custom_a/module_custom_a',
#             'objects': http.request.env['module_custom_a.module_custom_a'].search([]),
#         })

#     @http.route('/module_custom_a/module_custom_a/objects/<model("module_custom_a.module_custom_a"):obj>', auth='public')
#     def object(self, obj, **kw):
#         return http.request.render('module_custom_a.object', {
#             'object': obj
#         })

