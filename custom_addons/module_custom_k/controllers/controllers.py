# -*- coding: utf-8 -*-
# from odoo import http


# class ModuleCustomK(http.Controller):
#     @http.route('/module_custom_k/module_custom_k', auth='public')
#     def index(self, **kw):
#         return "Hello, world"

#     @http.route('/module_custom_k/module_custom_k/objects', auth='public')
#     def list(self, **kw):
#         return http.request.render('module_custom_k.listing', {
#             'root': '/module_custom_k/module_custom_k',
#             'objects': http.request.env['module_custom_k.module_custom_k'].search([]),
#         })

#     @http.route('/module_custom_k/module_custom_k/objects/<model("module_custom_k.module_custom_k"):obj>', auth='public')
#     def object(self, obj, **kw):
#         return http.request.render('module_custom_k.object', {
#             'object': obj
#         })

