#!/bin/bash
echo "received args: $@"
echo "running odoo --log-level=info $@"
exec odoo --log-level=info "$@"
