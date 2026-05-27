#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'sequel'
require 'json'
require 'dotenv/load'
require 'openssl'
require 'base64'
require 'time'

# ── Configuration ─────────────────────────────────────────────────────────────
set :app_file,       __FILE__
set :root,           File.dirname(__FILE__)
set :views,          File.join(settings.root, 'app/views')
set :public_folder,  File.join(settings.root, 'app/public')
set :bind,           '0.0.0.0'
set :port,           ENV.fetch('PORT', 4567).to_i
set :environment,    ENV.fetch('RACK_ENV', 'development').to_sym
set :session_secret, ENV.fetch('SESSION_SECRET', SecureRandom.hex(64))

enable :sessions
enable :logging
disable :show_exceptions if production?

# ── Database ──────────────────────────────────────────────────────────────────
DB_PATH = ENV.fetch('DATABASE_PATH', File.join(__dir__, 'db/workspace.db'))
FileUtils.mkdir_p(File.dirname(DB_PATH))

DB = Sequel.connect("sqlite://#{DB_PATH}")

# Run migrations
DB.create_table?(:config) do
  primary_key :id
  String  :key,        null: false, unique: true
  String  :value,      text: true
  String  :category,   default: 'general'
  DateTime :updated_at
end

DB.create_table?(:workspaces) do
  primary_key :id
  String   :name,        null: false
  String   :description, text: true
  String   :github_repo
  String   :github_branch, default: 'main'
  String   :status,      default: 'active'
  DateTime :last_synced
  DateTime :created_at
  DateTime :updated_at
end

DB.create_table?(:sync_log) do
  primary_key :id
  Integer  :workspace_id
  String   :action      # push / pull / clone
  String   :status      # success / error
  String   :message,    text: true
  String   :commit_sha
  DateTime :created_at
end

DB.create_table?(:services) do
  primary_key :id
  Integer  :workspace_id
  String   :name,        null: false
  String   :image
  String   :tag,         default: 'latest'
  String   :status,      default: 'stopped'
  String   :ports,       text: true  # JSON
  String   :env_vars,    text: true  # JSON
  String   :volumes,     text: true  # JSON
  DateTime :created_at
  DateTime :updated_at
end

# Seed default config
[
  { key: 'app_name',       value: 'PortableWork',   category: 'general' },
  { key: 'theme',          value: 'light',           category: 'ui' },
  { key: 'accent_color',   value: '#0071e3',         category: 'ui' },
  { key: 'github_token',   value: '',                category: 'github' },
  { key: 'github_user',    value: '',                category: 'github' },
  { key: 'auto_sync',      value: 'false',           category: 'sync' },
  { key: 'sync_interval',  value: '300',             category: 'sync' },
].each do |row|
  DB[:config].insert_ignore.insert(row.merge(updated_at: Time.now)) rescue nil
end

# ── Helpers ───────────────────────────────────────────────────────────────────
helpers Sinatra::ContentFor
helpers do
  def config(key)
    row = DB[:config].where(key: key).first
    row ? row[:value] : nil
  end

  def set_config(key, value, category = 'general')
    if DB[:config].where(key: key).count > 0
      DB[:config].where(key: key).update(value: value, updated_at: Time.now)
    else
      DB[:config].insert(key: key, value: value, category: category, updated_at: Time.now)
    end
  end

  def all_config
    DB[:config].all.group_by { |r| r[:category] }
  end

  def workspaces
    DB[:workspaces].order(:name).all
  end

  def sync_log(workspace_id = nil, limit = 20)
    q = DB[:sync_log].order(Sequel.desc(:created_at)).limit(limit)
    q = q.where(workspace_id: workspace_id) if workspace_id
    q.all
  end

  def services(workspace_id = nil)
    q = DB[:services].order(:name)
    q = q.where(workspace_id: workspace_id) if workspace_id
    q.all
  end

  def docker_running?
    system('docker info > /dev/null 2>&1')
  end

  def git_available?
    system('git --version > /dev/null 2>&1')
  end

  def run_git_command(cmd, dir = nil)
    full_cmd = dir ? "cd #{Shellwords.escape(dir)} && #{cmd}" : cmd
    output = `#{full_cmd} 2>&1`
    { success: $?.success?, output: output.strip }
  end

  def log_sync(workspace_id, action, status, message, sha = nil)
    DB[:sync_log].insert(
      workspace_id: workspace_id,
      action: action,
      status: status,
      message: message,
      commit_sha: sha,
      created_at: Time.now
    )
  end

  def api_response(data, status_code = 200)
    status status_code
    json data
  end

  def current_workspace
    session[:workspace_id] ? DB[:workspaces].where(id: session[:workspace_id]).first : nil
  end

  def format_time(t)
    return 'Never' unless t
    t = Time.parse(t.to_s)
    diff = Time.now - t
    case diff
    when 0..59      then "#{diff.to_i}s ago"
    when 60..3599   then "#{(diff/60).to_i}m ago"
    when 3600..86399 then "#{(diff/3600).to_i}h ago"
    else t.strftime('%b %d, %Y')
    end
  end
end

# ── Routes ────────────────────────────────────────────────────────────────────

# Dashboard
get '/' do
  @workspaces = workspaces
  @sync_log   = sync_log(nil, 10)
  @docker_ok  = docker_running?
  @git_ok     = git_available?
  @config     = all_config
  erb :index
end

# ── Workspace CRUD ─────────────────────────────────────────────────────────────

get '/workspaces' do
  @workspaces = workspaces
  erb :workspaces
end

post '/workspaces' do
  data = JSON.parse(request.body.read) rescue params
  now  = Time.now
  id = DB[:workspaces].insert(
    name:          data['name'],
    description:   data['description'],
    github_repo:   data['github_repo'],
    github_branch: data['github_branch'] || 'main',
    status:        'active',
    created_at:    now,
    updated_at:    now
  )
  api_response({ success: true, id: id, message: 'Workspace created' })
end

put '/workspaces/:id' do
  data = JSON.parse(request.body.read) rescue params
  DB[:workspaces].where(id: params[:id]).update(
    name:          data['name'],
    description:   data['description'],
    github_repo:   data['github_repo'],
    github_branch: data['github_branch'] || 'main',
    updated_at:    Time.now
  )
  api_response({ success: true, message: 'Workspace updated' })
end

delete '/workspaces/:id' do
  DB[:workspaces].where(id: params[:id]).delete
  api_response({ success: true, message: 'Workspace deleted' })
end

# ── GitHub Sync ────────────────────────────────────────────────────────────────

post '/sync/push/:workspace_id' do
  ws = DB[:workspaces].where(id: params[:workspace_id]).first
  halt 404, json({ error: 'Workspace not found' }) unless ws

  token   = config('github_token')
  message = params[:message] || request.body.read.then { |b| JSON.parse(b)['message'] rescue nil } || 'chore: sync workspace state'

  # Simulate git push with token auth
  repo = ws[:github_repo]
  branch = ws[:github_branch] || 'main'

  if token.to_s.empty? || repo.to_s.empty?
    log_sync(ws[:id], 'push', 'error', 'GitHub token or repo not configured')
    return api_response({ success: false, error: 'GitHub token or repo URL not configured' }, 422)
  end

  # Build authenticated URL
  auth_url = repo.gsub('https://', "https://#{token}@")
  work_dir = "/tmp/ws_#{ws[:id]}"

  # Clone or pull
  unless Dir.exist?(work_dir)
    result = run_git_command("git clone #{auth_url} #{work_dir}")
    unless result[:success]
      log_sync(ws[:id], 'push', 'error', result[:output])
      return api_response({ success: false, error: result[:output] }, 500)
    end
  else
    run_git_command("git -C #{work_dir} pull origin #{branch}")
  end

  # Copy DB snapshot
  FileUtils.mkdir_p("#{work_dir}/.workspace")
  FileUtils.cp(DB_PATH, "#{work_dir}/.workspace/workspace.db") if File.exist?(DB_PATH)

  # Commit and push
  sha = nil
  cmds = [
    "git -C #{work_dir} add -A",
    "git -C #{work_dir} -c user.email='workspace@portable' -c user.name='PortableWork' commit -m '#{message.gsub("'", "\\'")}' --allow-empty",
    "git -C #{work_dir} push origin #{branch}"
  ]

  cmds.each do |cmd|
    result = run_git_command(cmd)
    unless result[:success] || cmd.include?('commit')
      log_sync(ws[:id], 'push', 'error', result[:output])
      return api_response({ success: false, error: result[:output] }, 500)
    end
    sha = result[:output].match(/\[.*?(\h{7,})\]/)[1] rescue nil if cmd.include?('commit')
  end

  DB[:workspaces].where(id: ws[:id]).update(last_synced: Time.now)
  log_sync(ws[:id], 'push', 'success', "Pushed to #{repo}:#{branch}", sha)
  api_response({ success: true, message: "Pushed to #{branch}", sha: sha })
end

post '/sync/pull/:workspace_id' do
  ws = DB[:workspaces].where(id: params[:workspace_id]).first
  halt 404, json({ error: 'Workspace not found' }) unless ws

  token  = config('github_token')
  repo   = ws[:github_repo]
  branch = ws[:github_branch] || 'main'

  if token.to_s.empty? || repo.to_s.empty?
    log_sync(ws[:id], 'pull', 'error', 'GitHub token or repo not configured')
    return api_response({ success: false, error: 'GitHub token or repo URL not configured' }, 422)
  end

  auth_url = repo.gsub('https://', "https://#{token}@")
  work_dir = "/tmp/ws_#{ws[:id]}"

  if Dir.exist?(work_dir)
    result = run_git_command("git -C #{work_dir} pull origin #{branch}")
  else
    result = run_git_command("git clone -b #{branch} #{auth_url} #{work_dir}")
  end

  unless result[:success]
    log_sync(ws[:id], 'pull', 'error', result[:output])
    return api_response({ success: false, error: result[:output] }, 500)
  end

  # Restore DB if snapshot exists
  snapshot = "#{work_dir}/.workspace/workspace.db"
  if File.exist?(snapshot)
    FileUtils.cp(snapshot, DB_PATH)
    log_sync(ws[:id], 'pull', 'success', "Pulled and restored DB from #{branch}")
  else
    log_sync(ws[:id], 'pull', 'success', "Pulled from #{branch} (no DB snapshot)")
  end

  DB[:workspaces].where(id: ws[:id]).update(last_synced: Time.now)
  api_response({ success: true, message: "Pulled from #{branch}" })
end

# ── Services ───────────────────────────────────────────────────────────────────

get '/services' do
  @services = services
  @workspaces = workspaces
  erb :services
end

post '/services' do
  data = JSON.parse(request.body.read) rescue params
  now = Time.now
  id = DB[:services].insert(
    workspace_id: data['workspace_id'],
    name:         data['name'],
    image:        data['image'],
    tag:          data['tag'] || 'latest',
    ports:        data['ports'].to_json,
    env_vars:     data['env_vars'].to_json,
    volumes:      data['volumes'].to_json,
    status:       'stopped',
    created_at:   now,
    updated_at:   now
  )
  api_response({ success: true, id: id })
end

post '/services/:id/start' do
  svc = DB[:services].where(id: params[:id]).first
  halt 404, json({ error: 'Service not found' }) unless svc

  ports   = JSON.parse(svc[:ports].to_s) rescue []
  port_flags = ports.map { |p| "-p #{p}" }.join(' ')
  image   = "#{svc[:image]}:#{svc[:tag]}"
  name    = "pw_#{svc[:name].gsub(/[^a-z0-9]/, '_')}"

  result = run_git_command("docker run -d --name #{name} #{port_flags} #{image}")
  if result[:success]
    DB[:services].where(id: params[:id]).update(status: 'running', updated_at: Time.now)
    api_response({ success: true, message: "#{svc[:name]} started" })
  else
    api_response({ success: false, error: result[:output] }, 500)
  end
end

post '/services/:id/stop' do
  svc = DB[:services].where(id: params[:id]).first
  halt 404, json({ error: 'Service not found' }) unless svc

  name = "pw_#{svc[:name].gsub(/[^a-z0-9]/, '_')}"
  run_git_command("docker stop #{name} && docker rm #{name}")
  DB[:services].where(id: params[:id]).update(status: 'stopped', updated_at: Time.now)
  api_response({ success: true, message: "#{svc[:name]} stopped" })
end

delete '/services/:id' do
  DB[:services].where(id: params[:id]).delete
  api_response({ success: true })
end

# ── Settings ───────────────────────────────────────────────────────────────────

get '/settings' do
  @config = all_config
  erb :settings
end

post '/settings' do
  data = JSON.parse(request.body.read) rescue params
  data.each do |key, value|
    next if %w[splat captures].include?(key)
    set_config(key, value)
  end
  api_response({ success: true, message: 'Settings saved' })
end

# ── Docker Compose generation ──────────────────────────────────────────────────

get '/compose/:workspace_id' do
  ws = DB[:workspaces].where(id: params[:workspace_id]).first
  halt 404, 'Workspace not found' unless ws

  svcs = services(ws[:id])
  compose = generate_compose(ws, svcs)
  content_type 'text/yaml'
  attachment "docker-compose-#{ws[:name].downcase.gsub(/\s+/, '-')}.yml"
  compose
end

def generate_compose(ws, svcs)
  lines = ["version: '3.9'", "# Generated by PortableWork — #{ws[:name]}", "# #{Time.now.iso8601}", '', 'services:']

  svcs.each do |svc|
    ports   = JSON.parse(svc[:ports].to_s)   rescue []
    env     = JSON.parse(svc[:env_vars].to_s) rescue {}
    volumes = JSON.parse(svc[:volumes].to_s)  rescue []

    lines << "  #{svc[:name].downcase.gsub(/[^a-z0-9]/, '_')}:"
    lines << "    image: #{svc[:image]}:#{svc[:tag]}"
    lines << "    restart: unless-stopped"

    unless ports.empty?
      lines << '    ports:'
      ports.each { |p| lines << "      - \"#{p}\"" }
    end

    unless env.empty?
      lines << '    environment:'
      env.each { |k, v| lines << "      #{k}: \"#{v}\"" }
    end

    unless volumes.empty?
      lines << '    volumes:'
      volumes.each { |v| lines << "      - #{v}" }
    end

    lines << ''
  end

  lines.join("\n")
end

# ── API status ─────────────────────────────────────────────────────────────────

get '/api/status' do
  json({
    status:        'ok',
    version:       '1.0.0',
    docker:        docker_running?,
    git:           git_available?,
    workspaces:    DB[:workspaces].count,
    services:      DB[:services].count,
    uptime:        Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i,
    timestamp:     Time.now.iso8601
  })
end

get '/api/sync-log' do
  limit = params[:limit]&.to_i || 50
  json sync_log(nil, limit).map { |r|
    r.merge(created_at: r[:created_at]&.to_s)
  }
end
