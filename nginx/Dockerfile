FROM nginx:1.25-alpine

# Remove the symlinks
RUN rm -f /var/log/nginx/access.log /var/log/nginx/error.log

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Create log directory and files
RUN mkdir -p /var/log/nginx && \
    touch /var/log/nginx/access.log /var/log/nginx/error.log && \
    chown nginx:nginx /var/log/nginx/access.log /var/log/nginx/error.log

EXPOSE 8080
