# -*- coding: utf-8 -*-

# from odoo import models, fields, api


# class module_custom_k(models.Model):
#     _name = 'module_custom_k.module_custom_k'
#     _description = 'module_custom_k.module_custom_k'

#     name = fields.Char()
#     value = fields.Integer()
#     value2 = fields.Float(compute="_value_pc", store=True)
#     description = fields.Text()
#
#     @api.depends('value')
#     def _value_pc(self):
#         for record in self:
#             record.value2 = float(record.value) / 100

