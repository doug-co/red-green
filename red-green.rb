#!/usr/bin/ruby

require 'base64'
require 'optparse'
require_relative 'resources'
require_relative 'tag'
require_relative 'server.rb'
require_relative 'tester.rb'
require_relative 'web_load.rb'

# look for gems we require, exit if they are not installed
def gems_installed(list)
  ok = true
  result = list.map { |gem| [ gem, `gem list #{gem}`.chomp ] }
  result.each do |r|
    puts "'#{r[0]}' gem is not installed." if r[1].length == 0
    ok = r[1].length > 0 if ok
  end
  puts "use: gem install 'gem_name'  --> to install missing gems." if not ok
  return ok
end

exit if not gems_installed(['listen'])


# parse command line options
@options = { auto: false, config: "rg-conf.rb", port: 1800, project_path: "./", path: [] }
OptionParser.new do |opts|
  opts.banner = "Usage: red-green.rb [options]"

  opts.on("-a", "--auto", "auto start web browser") do |auto|
    @options[:auto] = auto
  end
  opts.on("-c", "--config FILE", "config file -- ruby file with test config and setup") do |conf|
    @options[:config] = conf
  end
  opts.on("-P", "--port N", Integer, "http server port") do |port|
    @options[:port] = port
  end
  opts.on("-B", "--base-path PATH", "base project path") do |path|
    @options[:project_path] = path
  end
  opts.on("-p", "--path PATH", "path relative to base-path to watch for file modify, add, remove events") do |path|
    @options[:path] << path
  end
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

# get list of test items from ARGV
@modules = ARGV
@modules = [ "unittests" ] if not @test_items or @test_items.length == 0

if File.exist?(@options[:config]) then
  load @options[:config]
else
  puts "expecting config file at: '#{@options[:config]}'"
  exit
end
Dir.chdir(@options[:project_path])

if @options[:path].length == 0 then
  puts "no watch path specified. Add one or more directories to watch using '-p' option"
  exit
else
  @options[:path].each do |path|
    if not File.exist?("#{@options[:project_path]}/#{path}") then
      puts "path: '#{path}' does not exist."
      exit
    end
  end
end

# load additional resources
Resources.load_file("red-green.js", '1.0', 'javascript for application specific behaviors', 'text/javascript')
exit if not init()
puts @options
Resources.show

# create tester object
@test = Tester.new(@options[:path]) { |mod, add, rem| test(mod, add, rem) }
@test.set_logger { |msg| log(msg) }

def template(page_title)
  port = @options[:port]
  serial = @test.value
  Tag.new() {
    def js_console(*args) append("console.log(\"#{args.join}\");\n") end
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
          css(:_term, :notification, background_color: '#202020', border_color: '#101040', color: '#00C000')
        }
      }
      body {
        div(id: "wrapper") {
          yield if block_given?
        }
        script(src: "/static/jquery.min.js")
        script(src: "/static/bootstrap.min.js")
        script(src: "/static/metismenu.min.js")
        script(src: "/static/sb-admin-2.js")
        script(src: "/static/red-green.js")
        script {
          jq_doc_ready {
            "red_green_init(#{serial})"
          }
        }
      }
    }
  }.result
end

def handle_get_root
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
              content[:all_post].call(tab) if content[:all_post]
            }
          }
          nil
        }
      end

      container {
        row {
          panel(12, 'default', "Status: Waiting for server to complete initial tests...", :status) {
            tabs([:git, :stdout, :console],
                 {all:    lambda { |tab| div(class: 'col-xs-12', style: 'height:25px;') { ' ' } },
                  git:    lambda { |tab| pre(id: "#{tab}-content") { "Loading..." } },
                  stdout: lambda { |tab| pre(id: "#{tab}-content", class: 'term', style: css(background_color: :black)) { "Loading..." } },
                  console:  lambda { |tab| pre(id: "#{tab}-content") { "loading..." } }
                 }
                )
          }
        }
          
        row { panel(12, 'yellow', "PyLint", :pylint) { div(id: 'pylint-content') { text { "loading..." } } } }
        row { panel(12, 'red', "Errors", :error) { pre(id: 'error-content') { text { "loading..." } } } }
      }
    }.result
  }
end

def log(msg) print "#{Time.now}: #{msg}\n" end

def serve_resource_id(server, id, path)
  if resource = Resources.list[id] then
    log("#{path} -- #{resource[:name]} #{resource[:type]} -- #{resource[:comment]}")
    server.make_response(resource[:type], resource[:gzip]) { resource[:data] }
  else
    nil
  end
end

url = "http://localhost:#{@options[:port]}"
puts "test server running on: #{url}"
server = HTTPServer.new('localhost', @options[:port]).start
server.set_logger { |msg| log(msg) }

server.handle(:static, [ :get ], /^\/static\/([^\/]+)$/) do |server, path, match|
  begin
    resp = serve_resource_id(server, Resources.name_index[match[1]][:key], path)
  rescue
    log("resource_name excpetion [#{path}]")
    resp = nil
  end
  resp
end

server.handle(:favicon, [ :get ], /^\/favicon\.ico/) do |server, path, match|
  serve_resource_id(server, "favicon_#{(@test.result[:result] == :ok) ? :green : :red}".to_sym, path)
end

server.handle(:poll, [:get ], /^\/poll\?q=(\d+)/) do |server, path, match|
  serial = match[1].to_i
  log("poll: handler [#{serial}]")
  server.make_response('application/json') do
    JSON.generate(@test.result(serial))
  end
end

server.handle(:root, [:get], /^\/$/) do |server, path, match|
  server.make_response { handle_get_root }
end

Thread.abort_on_exception = true

WebLoad.page(url) if @options[:auto]

server.thread.join
