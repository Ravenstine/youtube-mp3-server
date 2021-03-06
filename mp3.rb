require 'bundler'
Bundler.require
PROJECT_ROOT = Dir.pwd

class Transcoder < EM::Connection
  def initialize response
    @response = response
  end
  def receive_data data
    @response.chunk data
    @response.send_chunks
  end
  def unbind
    @response.close_connection
  end
end

class Server < EM::HttpServer::Server

  def process_http_request
    params = query_string_to_params(@http_query_string)
    response = EM::DelegatedHttpResponse.new(self)
    response.status = 200
    response.headers['Content-Type'] = 'audio/mp3'
    response.headers['Content-Transfer-Encoding'] = 'binary'
    response.headers["Transfer-encoding"] = "chunked"
    response.headers['Content-Disposition'] = "attachment; filename=\"#{params['id']}.mp3\""
    EM.defer proc {
      ViddlRb.get_urls("https://www.youtube.com/watch?v=#{params['id']}").first rescue nil
    }, proc { |video_url|
      cmd = "#{PROJECT_ROOT}/downloader.sh #{video_url}"
      EventMachine.popen(cmd, Transcoder, response)
    }
  rescue RuntimeError => e
    handle_error e
  rescue => e
    handle_error e
  end

  def handle_error e
    $stderr.puts e
  end

  def http_request_errback e
    handle_error e
  end
private
  def write_to_log *messages
    File.open("log.txt", "w") do |f|
      messages.each do |message|
        f.write message
      end
    end
  end
  def query_string_to_params query_string
    query_string.split("&").map{|x| {x.split("=")[0] => x.split("=")[1]}}.first rescue {}
  end
end

puts "                                                                                          
 __ __           _____      _           _____       ___    _____                          
|  |  | ___  _ _|_   _|_ _ | |_  ___   |     | ___ |_  |  |   __| ___  ___  _ _  ___  ___ 
|_   _|| . || | | | | | | || . || -_|  | | | || . ||_  |  |__   || -_||  _|| | || -_||  _|
  |_|  |___||___| |_| |___||___||___|  |_|_|_||  _||___|  |_____||___||_|   \\_/ |___||_|  
                                              |_|                                         
"
EM::run do
  EM::start_server("0.0.0.0", 8080, Server)
end
