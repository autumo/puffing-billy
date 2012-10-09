require 'cgi'
require 'uri'
require 'eventmachine'

module Billy
  class Proxy
    def initialize
      reset
    end

    def start
      Thread.new do
        EM.run do
          EM.error_handler do |e|
            puts e.class.name, e
            puts e.backtrace.join("\n")
          end

          @signature = EM.start_server('127.0.0.1', 0, ProxyConnection) do |p|
            p.handler = self
          end
        end
      end
      sleep(0.01) while @signature.nil?
    end

    def url
      "http://#{host}:#{port}"
    end

    def host
      'localhost'
    end

    def port
      Socket.unpack_sockaddr_in(EM.get_sockname(@signature)).first
    end

    def call(method, url, headers, body)
      Billy.log(:info, "#{method} #{url}")

      stub = find_stub(method, url)
      unless stub.nil?
        Billy.log(:info, "Stubbing #{method} #{url}")
        query_string = URI.parse(url).query || ""
        params = CGI.parse(query_string)
        stub.call(params, headers, body)
      end
    end

    def stub(url, options = {})
      ret = ProxyRequestStub.new(url, options)
      @stubs << ret
      ret
    end

    def reset
      @stubs = []
    end

    protected

    def find_stub(method, url)
      @stubs.each do |stub|
        return stub if stub.matches?(method, url)
      end
      nil
    end
  end
end
