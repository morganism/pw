#!/usr/bin/env ruby
# frozen_string_literal: true
# start.rb — Boots Puma with HTTPS (self-signed TLS)

require 'rack'
require 'puma'

ssl_key  = ENV.fetch('SSL_KEY',  File.join(__dir__, 'config/ssl/server.key'))
ssl_cert = ENV.fetch('SSL_CERT', File.join(__dir__, 'config/ssl/server.crt'))
port     = ENV.fetch('PORT', '4567').to_i
env      = ENV.fetch('RACK_ENV', 'development')

# Auto-generate self-signed cert in development
unless File.exist?(ssl_key) && File.exist?(ssl_cert)
  require 'fileutils'
  FileUtils.mkdir_p(File.dirname(ssl_key))
  puts "→ Generating self-signed TLS certificate..."
  system(
    "openssl req -x509 -nodes -days 3650 -newkey rsa:2048 " \
    "-keyout #{ssl_key} -out #{ssl_cert} " \
    "-subj '/CN=localhost/O=PortableWork' >/dev/null 2>&1"
  )
end

puts <<~BANNER
  ╔════════════════════════════════════════╗
  ║          PortableWork v1.0.0           ║
  ║   Secure Portable Workspace Manager   ║
  ╚════════════════════════════════════════╝
  → Environment : #{env}
  → Listening   : https://localhost:#{port}
  → TLS Key     : #{ssl_key}
  → TLS Cert    : #{ssl_cert}
  → Database    : #{ENV.fetch('DATABASE_PATH', './db/workspace.db')}
BANNER

# Load Rack app
app, _ = Rack::Builder.parse_file(File.join(__dir__, 'config.ru'))

server = Puma::Server.new(app)

# ✅ Supported TLS configuration (NO MiniSSL usage)
server.add_ssl_listener(
  '0.0.0.0',
  port,
  {
    key:  ssl_key,
    cert: ssl_cert,
    verify_mode: 'none'
  }
)

trap('INT')  { server.stop }
trap('TERM') { server.stop }

server.run
sleep
