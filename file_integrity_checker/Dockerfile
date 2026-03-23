# =============================================================================
# File Integrity Checker - Docker Testing Environment
# =============================================================================
# Base: Ubuntu 22.04 LTS
# Purpose: Test file integrity checking in isolated environment
# Includes: Mock file structure, cron support
# Note: Use docker-compose.yml to include MailHog for email testing
# =============================================================================

FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# -----------------------------------------------------------------------------
# Install Dependencies
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    sqlite3 \
    coreutils \
    findutils \
    mailutils \
    ssmtp \
    curl \
    wget \
    cron \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Create Mock Directory Structure
# -----------------------------------------------------------------------------
RUN mkdir -p /etc/myapp/config \
    /opt/application/data \
    /etc/nginx \
    /var/log/myapp

# Create test files
RUN echo "database_url: localhost" > /etc/myapp/config/app.yaml && \
    echo "log_level: info" >> /etc/myapp/config/app.yaml && \
    echo '{"name": "test-app", "version": "1.0.0"}' > /opt/application/data/config.json && \
    echo 'server { listen 80; }' > /etc/nginx/nginx.conf && \
    echo 'log message 1' > /var/log/myapp/app.log && \
    echo 'log message 2' >> /var/log/myapp/app.log

# -----------------------------------------------------------------------------
# Setup Application Directory
# -----------------------------------------------------------------------------
WORKDIR /app

# Copy application files
COPY config.ini /app/config.ini
COPY file_integrity_checker.sh /app/file_integrity_checker.sh

# Make script executable (ensure it works when volume mounted)
RUN chmod +x /app/file_integrity_checker.sh
# Ensure script can run even if volume mount changes permissions
RUN cp /app/file_integrity_checker.sh /usr/local/bin/file_integrity_checker.sh && \
    chmod +x /usr/local/bin/file_integrity_checker.sh

# Create log files
RUN touch /app/error_log.txt && chmod 666 /app/error_log.txt

# Configure ssmtp for MailHog
RUN echo "mailhub=mailhog:1025" > /etc/ssmtp/ssmtp.conf && \
    echo "UseTLS=NO" >> /etc/ssmtp/ssmtp.conf && \
    echo "FromLineOverride=YES" >> /etc/ssmtp/ssmtp.conf

# -----------------------------------------------------------------------------
# Supervisor Configuration for Background Services
# -----------------------------------------------------------------------------
RUN mkdir -p /var/log/supervisor

# Create supervisord config
RUN echo '[supervisord]' > /etc/supervisor/conf.d/supervisord.conf && \
    echo 'nodaemon=true' >> /etc/supervisor/conf.d/supervisord.conf

# -----------------------------------------------------------------------------
# Cron Configuration (disabled by default, enable in compose)
# -----------------------------------------------------------------------------
# Run every 5 minutes - enable by uncommenting in docker-compose
# RUN echo '*/5 * * * * root cd /app && /app/file_integrity_checker.sh --check >> /app/check.log 2>&1' > /etc/cron.d/file_integrity_checker
# RUN chmod 0644 /etc/cron.d/file_integrity_checker

# -----------------------------------------------------------------------------
# Expose Ports
# -----------------------------------------------------------------------------
# (No ports needed in container - handled by docker-compose)

# -----------------------------------------------------------------------------
# Start Command (can be overridden in docker-compose)
# -----------------------------------------------------------------------------
CMD ["/bin/bash"]
