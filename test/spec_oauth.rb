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

AUTHORIZE_SESSION = {
  :oauth_request_token => 'nice',
  :oauth_request_secret => 'yep'
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

  Rack::Lint.new(oauth)
end

def mock_callback(opts={})
  opts = {:valid_verifier => true,
    :valid_request_token => true,
    :valid_request_secret => true
  }.merge(opts)

  verifier = ''
  if opts[:valid_verifier]
    v = Rack::Utils.escape(opts[:verifier]) || 'gotit'
    verifier = "?oauth_verifier=#{v}"
  end

  sess = {}
  if opts[:valid_request_token]
    sess[:oauth_request_token] = AUTHORIZE_SESSION[:oauth_request_token]
  end

  if opts[:valid_request_secret]
    sess[:oauth_request_secret] = AUTHORIZE_SESSION[:oauth_request_secret]
  end

  path = '/oauth_callback' + verifier
  Rack::MockRequest.new(app).get(path, 'rack.session' => sess)
end

context 'Rack::OAuth' do

  context 'on login' do
    specify 'redirects the User to the Service Provider’s User Authorization URL' do
      res = Rack::MockRequest.new(app).get('/oauth_login', 'rack.session' => {})
      res.should.redirect
      res.location.should.equal('http://term.ie/oauth/authorize?oauth_token=requestkey')
      res.should.not.be.ok
    end

    specify 'throws 500 if the consumer key or secret is incorrect' do
      res = Rack::MockRequest.new(
                                  app(:consumer_secret => 'wrong')
                                  ).get('/oauth_login', 'rack.session' => {})
                                  
      res.status.should.equal 500

      res = Rack::MockRequest.new(
                                  app(:consumer_key => 'wrong')
                                  ).get('/oauth_login', 'rack.session' => {})
      res.status.should.equal 500
    end
  end

  context 'on callback' do
    # See http://oauth.net/core/1.0a and
    # http://wiki.oauth.net/Signed-Callback-URLs for info on
    # oauth_verifier and other security changes.
    specify 'passes control to the app behind it' do
      res = mock_callback
      res.body.should.equal('foo')
      res.should.be.ok
    end

    specify 'only deletes the access token, request token and request secret after the app behind it returns control'

    specify 'returns a 401 if the access token is not successfully gathered'

    specify 'returns a 400 if the oauth_request_token or oauth_request_secret is missing' do

      res = mock_callback(:valid_request_secret => false)

      res.should.be.a.client_error
      res.status.should.equal 400

      res = mock_callback(:valid_request_token => false)

      res.should.be.a.client_error
      res.status.should.equal 400
    end

    specify 'returns a 400 if the Service Provider did not append the OAuth 1.0a oauth_verifier param to the callback' do
      res = mock_callback(:valid_verifier => false)
      res.should.be.a.client_error
      res.status.should.equal 400
      res.match /verifier/
    end

    specify 'passes oauth_verifier to the the next app'
    specify 'includes the oauth_verifier of OAuth 1.0a in the access token request'
    specify 'wtf oauth_callback_accepted seems to be useless'
  end
end
