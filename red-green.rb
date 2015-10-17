#!/usr/bin/ruby

require 'open3'
require 'socket' # Provides TCPServer and TCPSocket classes
require 'listen'
require 'base64'
require 'json'
require_relative 'resources'

# get list of test items from ARGV
@modules = ARGV
@modules = [ "unittests" ] if not @test_items or @test_items.length == 0

@git = { std_out: "" }
@result = { result: :ok, app_out: "", output: ""}
@config = { listen_path: [ "#{ENV['HOME']}/Projects/Z0lverEdu/application", "#{ENV['HOME']}/Projects/Z0lverEdu/unittests" ],
            port: 8180
          }

# this is for managing status change events for threads
class Serial
  def initialize()
    super()
    @value = 0
    @mutex = Mutex.new
    @cond = ConditionVariable.new
  end
  def ready; ready = false; @mutex.synchronize { ready = @value > 0 };            return ready end
  def inc;                  @mutex.synchronize { @value += 1; @cond.broadcast() }              end
  def value; v = nil;       @mutex.synchronize { v = @value };                    return v     end
  def wait_for_serial(value, &block)
    target = 0
    @mutex.synchronize do
      target = @value + 1
      if value > @value then
        while (target > @value) do @cond.wait(@mutex) end
      end
    end
    return target
  end
end

@serial = Serial.new()

# read stdout and stderr form external commands
def system_with_stderr(cmd)
  values = nil

  Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
    values = { :stdout => stdout.read, :stderr => stderr.read }
  end

  return values
end

def run_tests(mod=nil)
  cmd = "nosetests --nocapture --logging-level=ERROR --with-gae --gae-application='unittests/test.yaml' #{mod or "unittests"}"

  test_results = system_with_stderr(cmd)
  result = (test_results[:stderr].split(/\n/)[-1] == "OK") ? :ok : :error

  { :result => result, :output => test_results[:stderr], :app_out => test_results[:stdout] }
end

def gems_installed(list)
  ok = true
  result = list.map { |gem| [ gem, `gem list #{gem}`.chomp ] }
  result.each { |r| puts "'#{r[0]}' gem is not installed." if r[1].length == 0; ok = r[1].length > 0 if ok }
  puts "use: gem install 'gem_name'  --> to install missing gems." if not ok
  return ok
end

exit if not gems_installed(['listen'])

class Tag
  def result; return @result__ end

  def self.strip(*args)
    translations={ :amp => '&', :quot => '"', :apos => "'", :lt => "<", :gt => ">" }
    args.map { |a|
      b = a.to_s.dup
      translations.each { |k,v| b.gsub!(/#{v}/,"&#{k};") }
      b
    }.join('')
  end

  def initialize(&block)
    @parent__ = [[]]
    @context__ = eval("self", block.binding)
    instance_eval &block
    @selector__ = []
    @result__ = @parent__.pop.join
  end

  def append(*args) @parent__.last.push( args.join ); nil end

  def css(name, *args)
    attribs = []
    def make_attrib(arg) (arg.class == Hash) ? arg.map { |k,v| k = k.to_s.gsub(/_/,'-'); (v.length > 0) ? "#{k}:#{v}" : k } : [ arg.to_s ] end

    if name.class == Hash then
      return '"' + make_attrib(name).join(';') + '"'
    else
      name = name.to_s
      name[0] = '.' if name[0] == '_'

      args.each { |arg| attribs += make_attrib(arg) }
      attribs += make_attrib(yield(name)) if block_given?
    
      append( name, '{', attribs.join(';') + ';', '}' )
    end
  end
  
  def tag(name, value, *args)
    end_tag_always = [ :script ]
    attribs = []
    args.each do |arg|
      if arg.class == Hash then
        arg.each_pair do |k,v|
          key = (k.class == Symbol) ? k.to_s.gsub(/_/,'-') : k
          attribs.push([key, '="', v.to_s.gsub(/"/,''), '"'].join)
        end
      end
    end
    if value.length > 0 or end_tag_always.include?(name) then
      append( attribs.unshift("<#{name}").join(' '), '>', "\n", value, "\n", "</#{name}>", "\n" )
    else
      append( attribs.unshift("<#{name}").join(' '), '/>', "\n" )
    end
  end
  
  def text(&block) append(Tag.strip(yield)) end

  def p(*args, &block) tag('p', [yield].flatten.join, *args) end

  def method_missing(name, *args, &block)
    if @context__ and @context__.respond_to?(name) then
      return @context__.send(name, *args, &block)
    else
      @parent__.push([])
      append([yield(name)].flatten.join(' ')) if block_given?
      tag(name, @parent__.pop.join, *args)
    end
  end
end

def template(page_title)
  port = @config[:port]
  serial = @serial.value
  Tag.new() {
    def js_console(*args) "console.log(\"#{args.join}\");" end
    def jq_doc_ready; ["$(document).ready(function() {", yield, "});"].join("\n") end
    html {
      head {
        title { page_title }
        link(href: "/static/bootstrap.min.css", rel: "stylesheet")
        link(href: "/static/metismenu.min.css", rel: "stylesheet", type: "text/css")
        link(href: "/static/sb-admin-2.css", rel: "stylesheet")
        link(href: "/static/font-awesome.min.css", rel: "stylesheet", type: "text/css")
        link(href: "http://localhost:#{port}/favicon.ico?v=#{Time.now.to_i}", rel: "shortcut icon")
        style {
#          css(:body, background_color: '#ffffff', font_family: '"Arial", Arial, sans-serif')
#          css(:_ok,  background_color: '#80C080', border_color: '#70A070')
#          css(:_error, background_color: '#C08080', border_color: '#A02020')
#          css(:_info, background_color: '#f0f0f0')
#          css(:_notification, padding: '5px', border: '2px solid', border_radius: '5px')
#          css(:_mrgn_r, margin_right: '5px')
#          css(:_mrgn_b, margin_bottom: '5px')
#          css(:_fltr, float: 'right')
          css(:_term, :notification, background_color: '#202020', border_color: '#101040', color: '#00C000')
#          css(:pre, font_family: '"courier new", courier, monospace"', font_size: '8px')
        }
      }
      body {
        div(id: "wrapper") { yield if block_given? }
        script(src: "/static/jquery.min.js")
        script(src: "/static/bootstrap.min.js")
        script(src: "/static/metismenu.min.js")
        script(src: "/static/sb-admin-2.js")
        script {
          <<-END_OF_JS

          function long_poll_d(serial) {
            console.log("poll start, serial: ", serial)
            $.ajax({url: '/poll', cache: false, data: { q : serial }, dataType: "json", timeout: 180000,
              // server returned, update and start next call to server
              success: function(data) {
                console.log("poll success!")
                poll_update(data)
                long_poll_d(data["serial"]+1)
              },
              // assume call timed out, try again
              error: function() {
                 console.log("poll error!")
                 long_poll_d(serial)
              }
            });
          }

          function poll_update(data) {
            console.log("poll update")
            console.log("poll data: ", data)
            $('#git-content').text(data["git"])
            $('#stdout-content').text(data["stdout"])
            $('#status').text(data["status"])
            $('#error-content').text(data["error"])
            status_panel = $('#status-panel')
            status_title = $('#status-title')
            error_panel  = $('#error-panel')
            if (data["status"] == "ok") {
              status_panel.addClass("panel-green")
              status_panel.removeClass("panel-red")
              status_title.text("Status: Pass")
              error_panel.hide()
            }
            else {
              status_panel.addClass("panel-red")
              status_panel.removeClass("panel-green")
              status_title.text("Status: Fail")
              error_panel.show()
            }
          }

          $(document).ready(function() {
            console.log("doc ready")
            long_poll_d(#{serial + 1})
          });
          END_OF_JS
        }
      }
    }
  }.result
end

def handle_get_root
  r_val = @result[:result]
  r_out = @result[:app_out]
  r_err = @result[:output]
  git_out = @git[:stdout]
  serial = @serial.value

  template("Test Watcher") {
    Tag.new() {
      def row; div(class: 'row') { yield } end
      def container; row { div(class: 'container') { yield } } end
      def well(grid_size) div(class: "col-lg-#{grid_size}") { div(class: "well well-sm") { yield } } end
      def panel(grid_size, type, title, id)
        div(class: "col-xs-#{grid_size}") {
          div(class: "panel panel-#{type}", id: "#{id}-panel") {
            div(class: "panel-heading") { span(id: "#{id}-title") { text { title } } }
            div(class: "panel-body") { yield }
          }
        }
      end
      def alert(type) div(class: "alert alert-#{type}") { yield } end
      def tabs(list, content={})
        ul(class: "nav nav-tabs") {
          list.each_with_index { |tab,i|
            li((i==0) ? {class: :active} : nil) { a(href: "##{tab}", data_toggle: :tab) { tab.to_s.capitalize } }
          }
          nil
        }
        div(class: 'tab-content') {
          list.each_with_index { |tab,i|
            div(class: "tab-pane fade#{(i==0) ? " in active" : ""}", id: tab) {
              content[:all].call(tab) if content[:all]
              content[:all_pre].call(tab) if content[:all_pre]
              if content[tab] then
                content[tab].call(tab)
              else
                h4 { "#{tab.to_s.capitalize} Tab" }
                p(id: "#{tab}-content") { "#{tab} content" }
              end
              ocontent[:all_post].call(tab) if content[:all_post]
            }
          }
          nil
        }
      end

      container {
        row {
          panel(12, 'default', "Status: Waiting for server to complete initial tests...", :status) {
            tabs([:git, :stdout],
                 {all:    lambda { |tab| div(class: 'col-xs-12', style: 'height:25px;') { ' ' } },
                  git:    lambda { |tab| pre(id: "#{tab}-content") { "Loading..." } },
                  stdout: lambda { |tab| pre(id: "#{tab}-content", class: 'term', style: css(background_color: :black)) { "Loading..." } }
                 }
                )
          }
        }
          
        row { panel(12, 'red', "Errors", :error) { pre(id: 'error-content') { text { "loading..." } } } }
      }
    }.result
  }
end

# @result = { result: "blah", app_out: "blah blah", output: "worgH" }
# @git = { stdout: "yip" }
# puts handle_get_root()
# exit

def log(msg) puts "#{Time.now}: #{msg}" end

def handle_get_poll(serial)
  log("poll: handler [#{serial}]")
  # wait for @serial to update, or just return if we are already behind
  serial = @serial.wait_for_serial(serial.to_i)
  status = (serial == 0) ? "starting" : @result[:result].to_s
  res = JSON.generate({ status: status, serial: serial, stdout: @result[:app_out], error: @result[:output], git: @git[:stdout] })
  log(res)
  return res
end

def resource_not_found(path)
  log("#{path} Not Found")
  make_response(nil, false, 404, "Not Found")
end

def serve_resource_id(id, path)
  if resource = Resources.list[id] then
    log("#{path} -- #{resource[:name]} #{resource[:type]} -- #{resource[:comment]}")
    make_response(resource[:type], resource[:gzip]) { resource[:data] }
  else
    nil
  end
end

def serve_resource_name(name, path)
  begin
    log("resource_name #{path}")
    serve_resource_id(Resources.name_index[name][:key], path)
  rescue
    log("resource_name excpetion")
    nil
  end
end

def handle_get(path)
  log "GET #{path}"
  value = nil
  case path
  when '/';                    value = make_response { handle_get_root }
  when /^\/poll\?q=(\d+)/;     value = make_response('application/json') { handle_get_poll($1) }
  when /^\/static\/([^\/]+)$/; value = serve_resource_name($1, path)
  when /^\/favicon.ico/;       value = serve_resource_id("favicon_#{(@result[:result] == :ok) ? :green : :red}", path)
  end
  (value) ? value : resource_not_found(path)
end

def handler(request)
  log "request:[#{request.chomp}]"
  case request
  when /GET\s+(.*)\s+HTTP/; handle_get($1)
  else; request =~ /\w+\s+(.*)\s+HTTP/; resource_not_found($1)
  end    
end

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
           
def update_status
  log("file change detected.")
  @result = run_tests(@modules.join(' '))
  @git = system_with_stderr("git status")
  @serial.inc
end

@dir = Dir.pwd
listener = Listen.to(*@config[:listen_path], ignore: /(^.?#|~$)/) do |mod, add, rem|
  @changes = mod + add + rem
  @changes.map! { |f| f.gsub(@dir+'/','') }
  @modules = @changes.map { |f| f =~ /^[^\/]+\/([^\/]+)/; $1 }.uniq

  update_status
end

Thread.abort_on_exception = true
Thread.start do
  update_status
end
listener.start

# Initialize a TCPServer object that will listen
# on localhost:2345 for incoming connections.
server = TCPServer.new('localhost', @config[:port])
puts "test server running on: http://localhost:#{@config[:port]}"

# loop infinitely, processing one incoming
# connection at a time.
loop do
  # Wait until a client connects, then return a TCPSocket
  # that can be used in a similar fashion to other Ruby
  # I/O objects. (In fact, TCPSocket is a subclass of IO.)
  Thread.start(server.accept) do |socket|
    # Read the first line of the request (the Request-Line)
    socket.print handler(socket.gets)

    # Close the socket, terminating the connection
    socket.close
  end
end

