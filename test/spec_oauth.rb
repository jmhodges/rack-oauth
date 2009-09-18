# -*- coding: utf-8 -*-
require 'test/spec'
require 'mocha'
require 'rack/oauth'
require 'rack/lint'
require 'rack/mock'
require 'rack/session/cookie'

DEFAULT = {
  :consumer_key => 'key',
  :consumer_secret => 'secret',
  :consumer_site => 'http://term.ie',
  :request_token_path => "/oauth/example/request_token.php",
  :access_token_path => "/oauth/example/access_token.php",
  :authorize_path => "/oauth/example/authorize.php"
}

def app(hsh={})
  inner_lint = Rack::Lint.new(lambda { |env|
                                [200,
                                 {"Content-type" => "test/plain",
                                   "Content-length" => "3"
                                 },
                                 ["foo"]
                                ]
                              })
  oauth = Rack::OAuth.new(inner_lint, DEFAULT.merge(hsh))
  Rack::Session::Cookie.new(Rack::Lint.new(oauth))
end

context 'Rack::OAuth' do

  context 'on login' do
    specify 'redirects the User to the Service Provider’s User Authorization URL' do
      res = Rack::MockRequest.new(app).get('/oauth_login')
      res.should.redirect
      res.location.should.equal('http://term.ie/oauth/authorize?oauth_token=requestkey')
      res.should.not.be.ok
    end

    specify 'throws 500 if the consumer key or secret is incorrect' do
      res = Rack::MockRequest.new(
                                  app(:consumer_secret => 'wrong')
                                  ).get('/oauth_login')
                                  
      res.status.should.equal 500

      res = Rack::MockRequest.new(
                                  app(:consumer_key => 'wrong')
                                  ).get('/oauth_login')
      res.status.should.equal 500
    end
  end

  context 'on callback' do
    specify 'passes control to the app behind it'
    specify 'requires an app to be behind it that can handle the callback path'
    specify 'only deletes the access token, request token and request secret after the app behind it returns control'
    specify 'returns a 4xx (FIXME DECIDE) if the access token is not successfuly gathered'
    specify 'returns a 4xx (FIXME DECIDE) if the oauth_request_token or oauth_request_secret is missing'
    specify 'requires the oauth_verifier of OAuth 1.0a as a parameter back from Service Provider'
    specify 'includes the oauth_verifier of OAuth 1.0a in the access token request'
    specify 'wtf oauth_callback_accepted seems to be useless'
  end
end
