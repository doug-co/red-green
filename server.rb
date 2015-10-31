require 'socket' # Provides TCPServer and TCPSocket classes

require_relative 'rg_logger'

class HTTPServer
  include RGLogger
  
  attr_reader :thread
  attr_accessor :logger
  
  # Initialize a TCPServer object that will listen
  # on localhost:2345 for incoming connections.
  def initialize(host, port)
    @server = TCPServer.new(host, port)
    @handlers = []
    @logger = nil
  end

  # def logger(&block) @log = block end
  # def log(msg) @log.call(msg) if @log end
  
  def start
    # loop infinitely, processing one incoming
    # connection at a time.
    @thread = Thread.start do
      loop do
        # Wait until a client connects, then return a TCPSocket
        # that can be used in a similar fashion to other Ruby
        # I/O objects. (In fact, TCPSocket is a subclass of IO.)
        Thread.start(@server.accept) do |socket|
          # Read the first line of the request (the Request-Line)
          request = socket.gets
          response = handle_request(request)
          begin
            socket.print response
          rescue Errno::EPIPE
            puts "socket connection closed unexpectedly?!#@!"
          end
          
          # Close the socket, terminating the connection
          socket.close
        end
      end
    end
    return self
  end

  # called from the main loop, this parses each request, then searches for a
  # handler that matches the request, then runs the associated handler code block
  # it passes the return value from the code block back as the response to the
  # request (handlers should use make_response to generate return values).
  def handle_request(request)
    if request =~ /^(\w+)\s+(.*)\s+HTTP/ then
      r_type = $1.downcase.to_sym
      path = $2
      log("Request: [#{r_type}] '#{path}'")
      found = false
      value = nil
      @handlers.each do |handler|
        if handler[:methods].index(r_type) != nil and handler[:expr].match(path) then
          found = true
          value = handler[:handler].call(self, path, Regexp.last_match)
          break
        end
      end
      (found and value) ? value : respond_resource_not_found(path)
    else
      make_response(type = "text/html", compressed = false, code = 400, msg = "Bad Request")
    end
  end

  # registers a handler, which adds the code block to the list of handlers
  def handle(name, r_type, expr, &block)
    @handlers.push({name: name, methods: r_type, expr: expr, handler: block})
  end

  # make a http response
  def make_response(type = "text/html", compressed = false, code = 200, msg = "OK", &block)
    response = [ "HTTP/1.1 #{code} #{msg}" ]
    result = (block_given?) ? yield : nil
    if result then 
      size = (result) ? result.bytesize : 0
      response += [ "Content-Type: #{type}",
                    "Content-Length: #{size}" ]
    end
    response += [ "Content-Encoding: gzip" ] if compressed
    response += [ "Connection: close", "" ]
    response.push(result) if result
    return response.join("\r\n")
  end

  # build a 400 error respnose
  def respond_bad_request; make_response(nil, false, 400, "Bad Request") end

  # build a 404 error response
  def respond_resource_not_found(path)
    log("#{path} Not Found")
    make_response(nil, false, 404, "Not Found")
  end
end
