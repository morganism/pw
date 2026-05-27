#!/usr/bin/env ruby
# frozen_string_literal: true
# start.rb — Boots Puma with HTTPS (self-signed TLS)

require 'rack'
require 'puma'
require 'puma/configuration'

ssl_key  = ENV.fetch('SSL_KEY',  File.join(__dir__, 'config/ssl/server.key'))
ssl_cert = ENV.fetch('SSL_CERT', File.join(__dir__, 'config/ssl/server.crt'))
port     = ENV.fetch('PORT', '4567')
workers  = ENV.fetch('WEB_CONCURRENCY', '1').to_i
threads  = ENV.fetch('RAILS_MAX_THREADS', '5')
env      = ENV.fetch('RACK_ENV', 'development')

# Auto-generate self-signed cert in development
unless File.exist?(ssl_key) && File.exist?(ssl_cert)
  require 'fileutils'
  FileUtils.mkdir_p(File.dirname(ssl_key))
  puts "→ Generating self-signed TLS certificate..."
  system(
    "openssl req -x509 -nodes -days 3650 -newkey rsa:2048 " \
    "-keyout #{ssl_key} -out #{ssl_cert} " \
    "-subj '/CN=localhost/O=PortableWork' 2>/dev/null"
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

# Puma config
#app = Rack::Builder.parse_file(File.join(__dir__, 'config.ru')).first
app = Rack::Builder.parse_file(File.join(__dir__, 'config.ru'))

server = Puma::Server.new(app)

# Add SSL binds
ctx = Puma::MiniSSL::Context.new
ctx.key  = ssl_key
ctx.cert = ssl_cert
ctx.verify_mode = Puma::MiniSSL::VERIFY_NONE

server.add_ssl_listener('0.0.0.0', port.to_i, ctx)

trap('INT')  { server.stop }
trap('TERM') { server.stop }

server.run.join
