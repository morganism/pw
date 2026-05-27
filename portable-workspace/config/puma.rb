# config/puma.rb — Puma configuration for PortableWork

ssl_key  = ENV.fetch('SSL_KEY',  File.join(__dir__, '../config/ssl/server.key'))
ssl_cert = ENV.fetch('SSL_CERT', File.join(__dir__, '../config/ssl/server.crt'))
port     = ENV.fetch('PORT', '4567')

threads_count = ENV.fetch('RAILS_MAX_THREADS', 5).to_i
threads threads_count, threads_count

workers ENV.fetch('WEB_CONCURRENCY', 1).to_i

preload_app!

if File.exist?(ssl_key) && File.exist?(ssl_cert)
  bind "ssl://0.0.0.0:#{port}?key=#{ssl_key}&cert=#{ssl_cert}&verify_mode=none"
else
  puts "⚠  TLS cert not found — falling back to HTTP on port #{port}"
  bind "tcp://0.0.0.0:#{port}"
end

pidfile ENV.fetch('PIDFILE', 'tmp/puma.pid')
state_path ENV.fetch('STATE_PATH', 'tmp/puma.state')

on_worker_boot do
  # Re-establish DB connection after fork
  DB.disconnect if defined?(DB)
end
