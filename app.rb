require 'sinatra'
require 'active_record'
require 'sinatra/activerecord'
require 'rake'
require 'aes'

SECRET_KEY = 'ghfbsfdvsnidtn54imvsledfmngiowmngvw433'

# set :database, 'sqlite3:base.db'
# set :show_exceptions, true

configure :development do
  set :database, 'sqlite3:dev.db'
  set :show_exceptions, true
end

configure :production do
  db = URI.parse(ENV['DATABASE_URL'] || 'postgres:///localhost/mydb')

  ActiveRecord::Base.establish_connection(
      :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
      :host     => db.host,
      :username => db.user,
      :password => db.password,
      :database => db.path[1..-1],
      :encoding => 'utf8'
  )
end

class Message < ActiveRecord::Base
  after_create :generate_token

  def generate_token
    update_column :token, SecureRandom.urlsafe_base64
  rescue ActiveRecord::RecordNotUnique
    retry
  end

end

get '/' do
  erb :create
end

post '/messages/save' do
  message = params['message']
  destroy_type = params['destruct_type']
  new_message = Message.create()
  new_message.message = AES.encrypt(message,SECRET_KEY)

  new_message.destroy_type = destroy_type
  if destroy_type == "visit"
    new_message.visits_to_destroy = params['visits']
  elsif destroy_type == "time"
    hours = params['hours'].to_i
    time = Time.now.to_datetime
    new_message.time_to_destroy = time + hours.hour
  end


  if new_message.save
    @message_url = request.base_url + "/message/" + new_message.token
    erb :token
  else
    'Message was not save'
  end

end

get '/message/:token' do
  token = params[:token]
  message = Message.where(token: token).first
  if message.nil?
    erb :not_found
  else

    if message.destroy_type == "visit"
        message.visits_to_destroy -= 1
        message.save
      @text_destroy = "Visits left: " + message.visits_to_destroy.to_s
    elsif message.destroy_type == "time"
      time_left = message.time_to_destroy - Time.now
      @text_destroy = "Time left: " + Time.at(time_left).utc.strftime("%H:%M:%S")
    end

    @text_message = AES.decrypt(message.message,SECRET_KEY)

    if message.destroy_type == "visit" and message.visits_to_destroy <= 0
      message.delete
    end

    if message.destroy_type == "time" and message.time_to_destroy - Time.now <=0
       message.delete
       @text_destroy = "Time left: " + Time.at(0).utc.strftime("%H:%M:%S")
    end


    erb :view

  end
end
