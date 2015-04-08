require 'bundler'
Bundler.require

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
    response = EM::DelegatedHttpResponse.new(self)
    response.status = 200
    response.headers['Content-Type'] = 'audio/mp3'
    response.headers['Content-Transfer-Encoding'] = 'binary'
    response.headers["Transfer-encoding"] = "chunked"
    response.headers['Content-Disposition'] = 'attachment; filename="stream.mp3"'
    params = query_string_to_params(@http_query_string)

    EM.defer proc {
      ViddlRb.get_urls("https://www.youtube.com/watch?v=#{params['id']}").first
    }, proc { |video_url|
      cmd = "curl '#{video_url}' | ffmpeg -i - -vn -f mp3 -"
      EventMachine.popen(cmd, Transcoder, response)
    }

  end

  def http_request_errback e
    puts e.inspect
  end
private
  def query_string_to_params query_string
    query_string.split("&").map{|x| {x.split("=")[0] => x.split("=")[1]}}.first rescue {}
  end
end


EM::run do
  EM::start_server("0.0.0.0", 1337, Server)
end