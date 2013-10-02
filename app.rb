require 'sinatra/base'
require 'sinatra/content_for'
require 'sinatra/config_file'
require 'sinatra/reloader'
require 'sinatra/partial'
require 'i18n'
require 'i18n/backend/fallbacks'
require 'omniauth'
require 'omniauth-salesforce'
require 'databasedotcom'
require 'haml'
require 'sass'

class MetaForce < Sinatra::Base
  use Rack::Session::Cookie
  register Sinatra::ConfigFile
  config_file "#{settings.root}/config.yml"

  configure :development do
    register Sinatra::Reloader
  end

  configure :production, :development do
    helpers Sinatra::ContentFor
    register Sinatra::Partial

    I18n.load_path += Dir[File.join(settings.root, 'locales', '*.yml')]
    I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
    I18n.locale = 'ja'

    enable :logging

    set :show_exceptions, :after_handler

    set :haml, { :format => :html5 }
    set :scss, { :style => :compact }
    set :instance_url, nil
    set :client_id, ENV['CLIENT_ID'] || settings.client_id
    set :client_secret, ENV['CLIENT_SECRET'] || settings.client_secret
    set :scope, 'id api web'
    set :debugging, development?
    set :version, 28.0

    use OmniAuth::Strategies::Salesforce, settings.client_id, settings.client_secret,
      :authorize_options => {
        :scope => settings.scope
      }
  end

  before do
    pass if request.path_info =~ /^\/auth\//

    redirect to('/auth/salesforce') unless client

    settings.instance_url ||= client.instance_url

    client.materialize("User") unless Module.const_defined?("User")
    unless current_user
      user = User.find(client.user_id)
      session[:current_user] = {
          :user_id => user['Id'],
          :user_name => user['Name'],
          :small_photo_url => user['SmallPhotoUrl']
        }
    end
  end

  get '/stylesheets/:name.css' do
    content_type 'text/css', :charset => 'utf-8'
    scss(:"/stylesheets/#{params[:name]}" )
  end

  get '/' do
    objects = client.describe_sobjects
    standard_objects = objects.select { |object| !object['custom'] }.sort{ |a,b| a['label'] <=> b['label'] }
    custom_objects = objects.select { |object| object['custom'] }.sort{ |a,b| a['label'] <=> b['label'] }
    @objects = standard_objects + custom_objects
    haml :index
  end

  get '/describe' do
    @sobject = client.describe_sobject params[:sobject]
    fields = @sobject['fields']
    standard_fields = fields.select { |field| !field['custom'] }.sort{ |a,b| a['label'] <=> b['label'] }
    custom_fields = fields.select { |field| field['custom'] }.sort{ |a,b| a['label'] <=> b['label'] }
    @fields = standard_fields + custom_fields
    haml :describe
  end

  get '/auth/salesforce/callback' do
    begin
      session[:client] = Databasedotcom::Client.new :client_id => settings.client_id, :client_secret => settings.client_secret, :version => settings.version, :debugging => settings.debugging
      session[:client].authenticate request.env['omniauth.auth']
    rescue Databasedotcom::SalesForceError => e
      request.env['rack.session'] = {}
      @message = e.message
      logger.error e
    end
    redirect to '/'
  end

  get '/auth/failure' do
    request.env['rack.session'] = {}
    redirect to '/'
  end

  get '/logout' do
    session[:client] = nil
    session[:current_user] = nil
    redirect to '/'
  end

  def client
    @client = session[:client]
    @client
  end

  def current_user
    session[:current_user]
  end

  def instance_url
    settings.instance_url
  end

  error Databasedotcom::SalesForceError do
    exception = env['sinatra.error']
    logger.error exception
    if exception.error_code == "INVALID_SESSION_ID"
      session[:client] = nil
      @message = I18n.t('message.error.session_is_invalid')
    else
      @message = I18n.t('message.error.something_wrong', :error => exception)
    end
    haml :error
  end

  run! if app_file == $0
end
