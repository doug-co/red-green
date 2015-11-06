
puts "config file loaded! do initialization here"

# show options (these can be changed by setting their values below)
puts "Options: #{@options}"

# it is possible to set option values here or in init()
@options[:project_path] = "#{ENV["HOME"]}/Projects/Z0lverEdu"
@options[:path] = [ 'unittests', 'application' ]

# do initialization, return false or nil to abort
def init
  true
end

# do any cleanup necessary
def cleanup
  true
end

def sys_cmd(cmd) Tester.system_pipe3(@options[:project_path], cmd) end

def pylint(files)
  msg_template = '{category}{module}{obj}{line}{column}{msg_id}{msg}'
  pylint_results = sys_cmd("pylint --rcfile=pylintrc #{(files).join(' ')} --msg-template='#{msg_template}' -r n -f html")

  # edit pylint output for sb-admin-2 
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
end

def nose(files)
  puts "nose files #{files}"
  files.map! { |f| f.gsub(@options[:project_path]+'/','') }
  modules = files.map { |f| f =~ /^[^\/]+\/([^\/]+)/; $1 }.uniq

  list = (files[0] and files[0] == '*') ? "unittests" : modules.join(' ')
  nose_out = sys_cmd("nosetests --nocapture --logging-level=ERROR --with-gae --gae-application='unittests/test.yaml' #{list}")
  nose_out[:status] = (nose_out[:stderr].split(/\n/)[-1] == "OK") ? :ok : :error
  nose_out
end

def git; sys_cmd("git status") end

# do testing
# return a Hash, at a minimum, return { status: result }
def test(mod, add, rem)
  nose_out = nose(mod + add + rem)
  git_out = git
  pylint_out = pylint(mod + add)
  
  { status: nose_out[:status], error: nose_out[:stderr], stdout: nose_out[:stdout],
    git: git_out[:stdout], pylint: pylint_out.join }
end
