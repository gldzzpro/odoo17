# -*- coding: utf-8 -*-
# from odoo import http


# class ModuleCustomD(http.Controller):
#     @http.route('/module_custom_d/module_custom_d', auth='public')
#     def index(self, **kw):
#         return "Hello, world"

#     @http.route('/module_custom_d/module_custom_d/objects', auth='public')
#     def list(self, **kw):
#         return http.request.render('module_custom_d.listing', {
#             'root': '/module_custom_d/module_custom_d',
#             'objects': http.request.env['module_custom_d.module_custom_d'].search([]),
#         })

#     @http.route('/module_custom_d/module_custom_d/objects/<model("module_custom_d.module_custom_d"):obj>', auth='public')
#     def object(self, obj, **kw):
#         return http.request.render('module_custom_d.object', {
#             'object': obj
#         })

