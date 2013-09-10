require 'rubygems'
require 'sinatra/base'
require 'lib/harp_runtime'
require 'logging'

class RootApp < Sinatra::Base

  configure :production, :development do
    enable :logging
  end

  configure :development do
    Logging.logger.root.add_appenders(Logging.appenders.stdout)
    Logging.logger.root.level = :debug
  end

  before do
    headers "Content-Type" => "text/html; charset=utf-8"
  end

  # Routes for Swagger UI to gather web resources
  get '/api-docs/' do
    send_file(File.join('public/docs', "harp-runtime.json"), {:type=>"json"})
  end

  # Routes for Swagger UI to gather web resources
  get %r{\/api-docs\/([^.]+).json} do |file|
    puts "Matched regex for #{file}, serving 'public/docs/#{file}.json'"
    send_file(File.join('public/docs', "#{file}.json"), {:type=>"json"})
  end

  get '/:lifecycle' do
    logger.info "Root handler"
    interpreter = Harp::HarpInterpreter.new
    if params.key?("lifecycle")
      puts "Got #{params[:lifecycle]}"
    end

    results = interpreter.play("sample/basic_webapp.harp", params[:lifecycle])
    erb :default, :locals => {:lifecycle => params[:lifecycle], :results => results}
  end

  get '/' do
    erb :welcome
  end

end