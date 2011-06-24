%w(rubygems sinatra redis haml oauth json weibo  date).each { |lib| require lib }

enable :sessions

Weibo::Config.api_key = "3926176445"
Weibo::Config.api_secret = "651156f9b786fdc0781376f3b121f359"

REDIS = Redis.new(:thread_safe=>true,:db=>1)

get '/' do
  if session[:atoken]
    redirect "/list"
  end
  "<a href='/connect'>授权，分享微博订阅</a><br><a href='/list'>变身（查看网友分享的微博订阅）</a>"
end

get "/list/:key" do |key|
      list = REDIS.get(key).split("&")
      oauth = Weibo::OAuth.new(Weibo::Config.api_key, Weibo::Config.api_secret)
      oauth.authorize_from_access(list[1], list[2])
      @nickname = list[0]
      @uid = key
      @timeline = Weibo::Base.new(oauth).friends_timeline({ 'count' => 20})
      Haml::Engine.new(File.read("./views/friend_timeline.haml")).render(self)
end
    
get "/list" do
    list = []
    list.push("<ul>")
    REDIS.keys.each do |key| 
        list.push("<li>查看<a target='_blank' href='/list/#{key}'>#{REDIS.get(key).split("&")[0]}</a>订阅的微博</li>")
    end
    list.push("</ul>")
    list.join("")
end

get '/connect' do
  oauth = Weibo::OAuth.new(Weibo::Config.api_key, Weibo::Config.api_secret)
  request_token = oauth.consumer.get_request_token
  session[:rtoken], session[:rsecret] = request_token.token, request_token.secret
  redirect "#{request_token.authorize_url}&oauth_callback=http://weibo.session.im/callback"
end

get '/callback' do
  oauth = Weibo::OAuth.new(Weibo::Config.api_key, Weibo::Config.api_secret)
  oauth.authorize_from_request(session[:rtoken], session[:rsecret], params[:oauth_verifier])
  session[:rtoken], session[:rsecret] = nil, nil
  session[:atoken], session[:asecret] = oauth.access_token.token, oauth.access_token.secret
  redirect "/verify_credentials"
end

get '/verify_credentials' do
    oauth = Weibo::OAuth.new(Weibo::Config.api_key, Weibo::Config.api_secret)
    oauth.authorize_from_access(session[:atoken], session[:asecret])
    credentials = Weibo::Base.new(oauth).verify_credentials
    puts credentials[:name] ,credentials[:id] ,credentials[:profile_image_url] ,credentials[:description]
    REDIS.set(credentials[:id], [credentials[:name],session[:atoken], session[:asecret]].join('&'))
    redirect "/list"
end

get '/logout' do
  session[:atoken], session[:asecret] = nil, nil
  redirect "/"
end
