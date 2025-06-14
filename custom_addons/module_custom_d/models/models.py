# -*- coding: utf-8 -*-

# from odoo import models, fields, api


# class module_custom_d(models.Model):
#     _name = 'module_custom_d.module_custom_d'
#     _description = 'module_custom_d.module_custom_d'

#     name = fields.Char()
#     value = fields.Integer()
#     value2 = fields.Float(compute="_value_pc", store=True)
#     description = fields.Text()
#
#     @api.depends('value')
#     def _value_pc(self):
#         for record in self:
#             record.value2 = float(record.value) / 100

