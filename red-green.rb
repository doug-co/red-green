#!/usr/bin/ruby

require 'open3'
require 'socket' # Provides TCPServer and TCPSocket classes
require 'listen'
require 'base64'
require 'json'

# get list of test items from ARGV
@modules = ARGV
@modules = [ "unittests" ] if not @test_items or @test_items.length == 0

@port = 8100
@refresh_secs = 5
@git = { std_out: "" }
@result = { result: :ok, app_out: "", output: ""}

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

# Favicon's base64 encoded
@favicon = { :green => "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",
  :red => "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"
}

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
  port = @port
  serial = @serial.value
  Tag.new() {
    def js_console(*args) "console.log(\"#{args.join}\");" end
    def jq_doc_ready; ["$(document).ready(function() {", yield, "});"].join("\n") end
    html {
      head {
        title { page_title }
        link(href: "//cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.5/css/bootstrap.min.css", rel: "stylesheet")
        link(href: "https://cdnjs.cloudflare.com/ajax/libs/metisMenu/2.2.0/metisMenu.min.css", rel: "stylesheet", type: "text/css")
        link(href: "http://ironsummitmedia.github.io/startbootstrap-sb-admin-2/dist/css/sb-admin-2.css", rel: "stylesheet")
        link(href: "http://maxcdn.bootstrapcdn.com/font-awesome/4.2.0/css/font-awesome.min.css", rel: "stylesheet", type: "text/css")
        link(href: "http://localhost:#{port}/favicon.ico?v=#{Time.now.to_i}", rel: "shortcut icon")
        style {
          css(:body, background_color: '#ffffff', font_family: '"Arial", Arial, sans-serif')
          css(:_ok,  background_color: '#80C080', border_color: '#70A070')
          css(:_error, background_color: '#C08080', border_color: '#A02020')
          css(:_info, background_color: '#f0f0f0')
          css(:_notification, padding: '5px', border: '2px solid', border_radius: '5px')
          css(:_mrgn_r, margin_right: '5px')
          css(:_mrgn_b, margin_bottom: '5px')
          css(:_fltr, float: 'right')
          css(:_term, :notification, background_color: '#202020', border_color: '#101040', color: '#00C000')
          css(:pre, font_family: '"courier new", courier, monospace"', font_size: '8px')
        }
      }
      body {
        div(id: "wrapper") { yield if block_given? }
        script(src: "https://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js")
        script(src: "https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.5/js/bootstrap.min.js")
        script(src: "https://cdnjs.cloudflare.com/ajax/libs/metisMenu/2.2.0/metisMenu.min.js")
        script(src: "http://ironsummitmedia.github.io/startbootstrap-sb-admin-2/dist/js/sb-admin-2.js")
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

def handle_get_favicon
  icon = (@result[:result] == :ok) ? :green : :red
  log("favicon icon: #{icon}")
  return Base64.decode64(@favicon[icon])
end

def handle_get_poll(serial)
  log("poll: handler [#{serial}]")
  # wait for @serial to update, or just return if we are already behind
  serial = @serial.wait_for_serial(serial.to_i)
  status = (serial == 0) ? "starting" : @result[:result].to_s
  res = JSON.generate({ status: status, serial: serial, stdout: @result[:app_out], error: @result[:output], git: @git[:stdout] })
  log(res)
  return res
end

def handle_get(path)
  log "#{Time.now} GET #{path}"
  case path
  when '/'; make_response { handle_get_root }
  when /^\/poll\?q=(\d+)/; make_response('application/json') { handle_get_poll($1) }
  when /^\/favicon.ico/; make_response('image/jpg') { handle_get_favicon }
  else; log("#{path} Not Found"); make_response(nil, 404, "Not Found")
  end
end

def handler(request)
  case request
  when /GET\s+(.*)\s+HTTP/; handle_get($1)
  else; make_response(nil, 404, "Not Found")
  end    
end

def make_response(type = "text/html", code = 200, msg = "OK", &block)
  response = [ "HTTP/1.1 #{code} #{msg}" ]
  result = (block_given?) ? yield : nil
  if result then 
    size = (result) ? result.bytesize : 0
    response += [ "Content-Type: #{type}",
                  "Content-Length: #{size}" ]
  end
  response += ["Connection: close", "" ]
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
listener = Listen.to('application', 'unittests', ignore: /(^.?#|~$)/) do |mod, add, rem|
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
server = TCPServer.new('localhost', @port)
puts "test server running on: http://localhost:#{@port}"

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

