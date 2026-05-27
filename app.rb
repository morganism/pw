require 'sinatra'

get '/' do
  'Hello, World!'
end

get '/health' do
  routes = Sinatra::Application.routes['GET'].map { |r| r[0] }
  
  health_data = {
    status: "OK",
    #uptime: (Time.now - settings.start_time).round(2),
    verified_routes: routes,
    timestamp: Time.now
  }

  content_type :json
  health_data.to_json
end
