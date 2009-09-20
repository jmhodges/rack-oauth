require 'rubygems'
require 'rack'
require 'oauth'

module Rack #:nodoc:

  # Rack Middleware for integrating OAuth into your application
  #
  # Note: this *requires* that a Rack::Session middleware be enabled
  #
  class OAuth

    DEFAULT_OPTIONS = {
      :login_path    => '/oauth_login',
      :callback_path => '/oauth_callback',
      :redirect_to   => '/oauth_complete',
      :session_key   => 'oauth_user',
    }

    # [internal] the URL that should initiate OAuth and redirect to the OAuth provider's login page
    attr_accessor :login_path
    alias login  login_path
    alias login= login_path=

    # [internal] the URL that the OAuth provider should callback to after OAuth login is complete
    attr_accessor :callback_path
    alias callback  callback_path
    alias callback= callback_path=

    # [external] the URL that Rack::OAuth should redirect to after the OAuth has been completed (part of your app)
    attr_accessor :redirect_to
    alias redirect  redirect_to
    alias redirect= redirect_to=

    # the name of the Session key to use to store user account information (if OAuth completed OK)
    attr_accessor :session_key

    # [required] Your OAuth consumer key
    attr_accessor :consumer_key
    alias key  consumer_key
    alias key= consumer_key=

    # [required] Your OAuth consumer secret
    attr_accessor :consumer_secret
    alias secret  consumer_secret
    alias secret= consumer_secret=

    # [required] The site you want to request OAuth for, eg. 'http://twitter.com'
    attr_accessor :consumer_site
    alias site  consumer_site
    alias site= consumer_site=

    # The path OAuth should use to get a request token from the OAuth
    # provider. OAuth will default to +/oauth/request_token+ without it.
    attr_accessor :request_token_path

    # The path OAuth should use to get a access token from the OAuth
    # provider. OAuth will default to +/oauth/access_token+ without it.
    attr_accessor :access_token_path

    # The path OAuth should use for the User Authorization URL. OAuth
    # will default to +/oauth/authorize+ without it.
    attr_accessor :authorize_path

    def initialize app, options = {}
      @app = app
      
      DEFAULT_OPTIONS.each {|name, value| send "#{name}=", value }
      options.each         {|name, value| send "#{name}=", value } if options

      raise_validation_exception unless valid?
    end

    def call env
      case env['PATH_INFO']
      when login_path;      do_login     env
      when callback_path;   do_callback  env
      else;                 @app.call    env
      end
    end

    def do_login env
      host_name = env['HTTP_HOST'] || env['SERVER_NAME']
      request = consumer.get_request_token(:oauth_callback =>
                                           URI.join("http://#{host_name}", callback_path).to_s)
      unless request.token && request.secret
        return consumer_key_or_secret_error
      end

      session(env)[:oauth_request_token]  = request.token
      session(env)[:oauth_request_secret] = request.secret

      # FIXME should the Content-type header should be checked against what
      # the client is Accept'ing and use something along those
      # lines in case of stringent clients?
      authorize_redirect(request)
    end

    def do_callback env
      request = Rack::Request.new(env)
      sess = request.session

      unless sess[:oauth_request_token] && sess[:oauth_request_secret]
        return missing_request_token_or_secret_error
      end

      oauth_verifier = request.params['oauth_verifier']
      
      unless oauth_verifier && !oauth_verifier.empty?
        return missing_oauth_verifier
      end

      request = ::OAuth::RequestToken.new(consumer,
                                           sess[:oauth_request_token],
                                           sess[:oauth_request_secret]
                                           )
      begin
        access = request.get_access_token(:oauth_verifier => oauth_verifier)
      rescue ::OAuth::Unauthorized
        return incorrect_oauth_request_information
      end

      env['rack.auth.oauth.access.token'] = access.token
      env['rack.auth.oauth.access.secret'] = access.secret
      @app.call(env)
    end

    protected

    def consumer
      options = {:site => consumer_site}
      options[:request_token_path] = request_token_path if request_token_path
      @consumer ||= ::OAuth::Consumer.new consumer_key, consumer_secret, options
    end

    def valid?
      @errors = []
      @errors << ":consumer_key option is required"    unless consumer_key
      @errors << ":consumer_secret option is required" unless consumer_secret
      @errors << ":consumer_site option is required"   unless consumer_site
      @errors.empty?
    end

    def raise_validation_exception
      raise @errors.join(', ')
    end

    def session env
      if env['rack.session'].nil?
        raise "rack.session is nil and this is a FIXME. use rack.errors?"
      end
      env['rack.session']
    end

    private

    def consumer_key_or_secret_error
      msg = "Whoa, OAuth was given the wrong consumer key or secret"
      [500, {'Content-type' => 'text/plain', 'Content-length' => msg.size.to_s}, [msg]]
    end

    def authorize_redirect(request)
      [302, {'Location' => request.authorize_url, 'Content-type' => 'text/plain'}, []]
    end

    def missing_request_token_or_secret_error
      msg = "Whoa, the redirect (or link) that sent you here didn't specify " +
        "either a oauth_request_token or oauth_request_secret"
      [400, {'Content-type' => 'text/plain', 'Content-length' => msg.size.to_s}, [msg]]
    end

    def missing_oauth_verifier
      msg = "Ah, the service you tried to talk to is not secure. We're not going " +
        "any further. (Specifically, it does not implement the oauth_verifier of " +
        "OAuth 1.0a.)"
      [400, {'Content-type' => 'text/plain', 'Content-length' => msg.size.to_s}, [msg]]
    end

    def incorrect_oauth_request_information
      msg = "Someone's been forgin'!"
      [401, {'Content-type' => 'text/plain', 'Content-length' => msg.size.to_s}, [msg]]
    end
  end

  module Auth #:nodoc:

    class OAuth

    end

  end

end
