require_relative 'app'

# Force HTTPS redirect in production
if ENV['RACK_ENV'] == 'production'
  use Rack::Protection::HttpsEnforcer rescue nil
end

run Sinatra::Application
