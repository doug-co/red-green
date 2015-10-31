#!/usr/bin/ruby

require 'open3'
require 'socket' # Provides TCPServer and TCPSocket classes
require 'base64'
require_relative 'resources'
require_relative 'tag'
require_relative 'server.rb'
require_relative 'tester.rb'

# get list of test items from ARGV
@modules = ARGV
@modules = [ "unittests" ] if not @test_items or @test_items.length == 0

proj_p = "#{ENV['HOME']}/Projects/Z0lverEdu"
@config = { project_path: proj_p,
            listen_path: [ "#{proj_p}/application", "#{proj_p}/unittests" ],
            port: 8180
          }

puts @config

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

# load additional resources
Resources.load_file("red-green.js", '1.0', 'javascript for application specific behaviors', 'text/javascript')

Resources.show

#@serial = Serial.new()
@test = Tester.new(@config[:listen_path]) do |mod, add, rem|
  changes = mod + add + rem
  changes.map! { |f| f.gsub(@config[:project_path]+'/','') }
  modules = changes.map { |f| f =~ /^[^\/]+\/([^\/]+)/; $1 }.uniq

  cmd = "nosetests --nocapture --logging-level=ERROR --with-gae --gae-application='unittests/test.yaml' #{modules.join(' ') or "unittests"}"

  test_results = Tester.system_pipe3(@config[:project_path], cmd)
  git_results = Tester.system_pipe3(@config[:project_path], "git status")
  pylint_cmd = "pylint --rcfile=pylintrc #{(mod+add).join(' ')} -r n -f html"
  pylint_results = Tester.system_pipe3(@config[:project_path], pylint_cmd)
  # modify pylint output for sb-admin-2
  pylint_out = pylint_results[:stdout].split[3..-4]
  pylint_out[2] = '<table class="table">'
  pylint_out.insert(2, '<div class="table-responsive">')
  pylint_out.insert(-1, '</div>')
  pylint_out.delete_if { |item| item =~ /^class=\"(even|odd)/ }
  pylint_out.each_index do |i|
    map = { 'error' => 'danger', 'warning' => 'warning', 'refactor' => 'info' }
    if pylint_out[i] == "<tr" then
      next if pylint_out[i+1] =~ /header/
      pylint_out[i+1] =~ /\>(.*)\</
      pylint_out[i] += ' class="' + (map[$1] || "") + '">'
    end
  end
  result = (test_results[:stderr].split(/\n/)[-1] == "OK") ? :ok : :error

  { :status => result, :error => test_results[:stderr], :stdout => test_results[:stdout],
    :git => git_results[:stdout], :pylint => pylint_out.join("\n") }
end
@test.set_logger { |msg| log(msg) }

def template(page_title)
  port = @config[:port]
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

puts "test server running on: http://localhost:#{@config[:port]}"
server = HTTPServer.new('localhost', @config[:port]).start
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

server.thread.join
