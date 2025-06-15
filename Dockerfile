FROM odoo:17

USER root

# Install additional dependencies if needed
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Copy custom entrypoint script
COPY banks.sh /banks.sh
RUN chmod +x /banks.sh

# Set working directory
WORKDIR /mnt/extra-addons

# Configure Odoo
EXPOSE 8069
EXPOSE 8072

# Switch back to odoo user for security
USER odoo

ENTRYPOINT ["/banks.sh"]
