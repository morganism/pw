#!/usr/bin/env ruby

require 'fileutils'

def prompt(message, default = nil)
  print "#{message}#{" [#{default}]" if default}: "
  input = gets.strip
  input.empty? ? default : input
end

app_name = prompt("Enter application name", "my_sinatra_app")
port = prompt("Enter port number", "4567")

app_dir = File.expand_path(app_name)
if Dir.exist?(app_dir)
  puts "❌ Directory '#{app_name}' already exists!"
  exit(1)
end

Dir.mkdir(app_dir)
puts "🚀 Creating Sinatra app in '#{app_name}' on port #{port}..."

# Template files
TEMPLATE_FILES = {
  'app.rb' => <<~RUBY,
    require 'sinatra'

    get '/' do
      'Hello, World!'
    end
  RUBY

  'Gemfile' => <<~RUBY,
    source 'https://rubygems.org'
    
    gem 'sinatra'
  RUBY

  'config.ru' => <<~RUBY,
    require './app'
    run Sinatra::Application
  RUBY

  'Dockerfile' => <<~DOCKER,
    FROM ruby:3.2

    WORKDIR /app

    COPY Gemfile Gemfile.lock ./
    RUN bundle install

    COPY . .

    CMD ["rackup", "--host", "0.0.0.0", "--port", "#{port}"]
  DOCKER

  'docker-compose.yaml' => <<~YAML,
    version: '3.8'
    services:
      app:
        build: .
        ports:
          - "#{port}:#{port}"
        volumes:
          - ./app_data:/app_data 
  YAML

  'Gemfile.lock' => ''
}

# Create files
TEMPLATE_FILES.each do |file, content|
  file_path = File.join(app_dir, file)
  File.write(file_path, content)
  puts "✅ Created: #{file}"
end

puts "\n🎉 Setup complete!"
puts "To start your app:"
puts "  cd #{app_name}"
puts "  docker-compose up --build"

