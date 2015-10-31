
puts "config file loaded! do initialization here"

# set options to defaults that make some sense
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

# do testing
# return a Hash, at a minimum, return { status: result }
def test(mod, add, rem)
  proj_path = @options[:project_path]
  changes = mod + add + rem
  changes.map! { |f| f.gsub(proj_path+'/','') }
  modules = changes.map { |f| f =~ /^[^\/]+\/([^\/]+)/; $1 }.uniq
  
  cmd = "nosetests --nocapture --logging-level=ERROR --with-gae --gae-application='unittests/test.yaml' #{modules.join(' ') or "unittests"}"
  
  test_results = Tester.system_pipe3(proj_path, cmd)
  git_results = Tester.system_pipe3(proj_path, "git status")
  pylint_cmd = "pylint --rcfile=pylintrc #{(mod+add).join(' ')} -r n -f html"
  pylint_results = Tester.system_pipe3(proj_path, pylint_cmd)
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
  
  { status: result, error: test_results[:stderr], stdout: test_results[:stdout],
    git: git_results[:stdout], pylint: pylint_out.join("\n") }
end
