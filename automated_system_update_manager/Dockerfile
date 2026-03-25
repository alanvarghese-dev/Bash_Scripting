# =============================================================================
# System Update Manager - Docker Test Environment
# =============================================================================
# Purpose: Provide isolated Ubuntu environment for testing
# Usage: docker build -t um .
# =============================================================================

FROM ubuntu:22.04

LABEL maintainer="DevOps Team"
LABEL version="1.0.0"
LABEL description="System Update Manager Test Environment"

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install required packages
RUN apt-get update && apt-get install -y \
    bash \
    coreutils \
    sqlite3 \
    findutils \
    dpkg \
    apt-utils \
    curl \
    vim \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Create required directories
RUN mkdir -p \
    /usr/local/bin \
    /etc/update_manager \
    /var/lib/update_manager/backups \
    /var/lib/update_manager/rollback \
    /var/log/update_manager \
    /var/lock

# Copy script files
COPY update_manager.sh /usr/local/bin/
COPY config.ini /etc/update_manager/

# Set permissions
RUN chmod 750 /usr/local/bin/update_manager.sh \
    && chmod 640 /etc/update_manager/config.ini

# Copy test files
COPY tests/ /tests/
RUN chmod +x /tests/*.sh

# Set working directory
WORKDIR /app

# Create entrypoint script
RUN echo '#!/bin/bash' > /entrypoint.sh \
    && echo 'set -e' >> /entrypoint.sh \
    && echo '' >> /entrypoint.sh \
    && echo '# Initialize apt cache' >> /entrypoint.sh \
    && echo 'apt-get update >/dev/null 2>&1 || true' >> /entrypoint.sh \
    && echo '' >> /entrypoint.sh \
    && echo 'exec "$@"' >> /entrypoint.sh \
    && chmod +x /entrypoint.sh

# Default command
CMD ["/bin/bash"]