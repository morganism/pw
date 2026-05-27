FROM ruby:3.2-alpine

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    sqlite-dev \
    git \
    openssl \
    openssl-dev \
    curl \
    bash \
    docker-cli

WORKDIR /app

# Install gems
COPY Gemfile Gemfile.lock* ./
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy application
COPY . .

# Create dirs
RUN mkdir -p db log tmp

# Generate self-signed TLS cert
RUN mkdir -p /app/config/ssl && \
    openssl req -x509 -nodes -days 3650 \
      -newkey rsa:2048 \
      -keyout /app/config/ssl/server.key \
      -out    /app/config/ssl/server.crt \
      -subj "/C=US/ST=Local/L=Local/O=PortableWork/CN=localhost" 2>/dev/null

EXPOSE 4567

ENV RACK_ENV=production
ENV PORT=4567
ENV DATABASE_PATH=/app/db/workspace.db

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -k -f https://localhost:4567/api/status || exit 1

CMD ["bundle", "exec", "ruby", "start.rb"]
