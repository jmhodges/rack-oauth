# -*- coding: utf-8 -*-
require 'test/spec'
require 'mocha'
require 'rack/oauth'
require 'rack/lint'
require 'rack/mock'
require 'rack/session/cookie'
DEFAULT = {
  :consumer_key => 'my_consumer_key',
  :consumer_secret => 'my_consumer_secret',
  :consumer_site => 'http://twitter.com',
}

class OAuth::Consumer
  # We need to make sure we don't call out over HTTP.
  def request(*args)
    raise "Oh no you don't: #{args.inspect}"
  end
end

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

  def mock_http_response(code, body)
    mock('Net::HTTP') do |m|
      stubs('code').returns(code.to_s)
      stubs('body').returns(body)
      stubs('error!').returns do
        raise Net::HTTP::CODE_TO_OBJ[code.to_s].new("shoot: #{code}", self)
      end
    end
  end

  def twitter_request_token_response
    body = "oauth_token=good_oauth_token&oauth_token_secret=good_token_secret&oauth_callback_confirmed=true"
    mock_http_response(200, body)
  end

  
context 'Rack::OAuth' do

  context 'on login' do
    setup do
    OAuth::Consumer.
        any_instance.
        expects(:request).
        with(:post, "/oauth/request_token", nil, {:oauth_callback=>"http:/oauth_callback"}).
        returns(twitter_request_token_response)
    end
    
    specify ', on login, redirects the User to the Service Provider’s User Authorization URL' do
      res = Rack::MockRequest.new(app).get('/oauth_login')
    res.should.be.redirect
    end
  end
end
