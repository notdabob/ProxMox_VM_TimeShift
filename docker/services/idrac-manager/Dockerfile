# iDRAC Management Container
# Provides web-based dashboard for Dell iDRAC6 server management
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    cron \
    curl \
    iputils-ping \
    jq \
    net-tools \
    nginx \
    nmap \
    openssh-client \
    procps \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Create application directory
WORKDIR /app

# Copy application files
COPY src/ /app/src/
COPY docker/ /app/docker/

# Create necessary directories
RUN mkdir -p /app/data \
    /app/logs \
    /app/www \
    /var/log/supervisor \
    /root/.ssh

# Install Python dependencies
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy nginx configuration
COPY docker/nginx.conf /etc/nginx/sites-available/default

# Copy supervisor configuration
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy startup script
COPY docker/start.sh /app/start.sh
RUN chmod +x /app/start.sh && \
    chown -R www-data:www-data /app/www

# Expose ports
EXPOSE 80 8765

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Start services
CMD ["/app/start.sh"]