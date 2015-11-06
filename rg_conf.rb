
puts "config file loaded! do initialization here"

# show options (these can be changed by setting their values below)
puts "Options: #{@options}"

# it is possible to set option values here or in init()
# @options[:project_path] = "#{ENV['HOME']}/my_project"

# do initialization, return false or nil to abort and exit
def init
  true
end

# do any cleanup necessary
def cleanup
  true
end

def sys_cmd(cmd) Tester.system_pipe3(@options[:project_path], cmd) end

def git; sys_cmd("git status") end

def ruby(mod, add, rem)
  puts "mod: #{mod}, add: #{add}, rem: #{rem}"
  ruby_out = sys_cmd("ruby test.rb")
  ruby_out[:status] = (ruby_out[:stdout].chomp.split("\n")[-1] =~ /0 failures/) ? :ok : :error
  if ruby_out[:status] == :error then
    if ruby_out[:stdout] =~ /(1\)\s+Failure.*)\n+\d+\sruns,/m then
      ruby_out[:stderr] = "" if ruby_out[:stderr] == nil
      ruby_out[:stderr] += $1
      ruby_out[:stdout].sub!(/(1\)\s+Failure.*)\n+\d+\sruns,/m,"")
    end
  end
  ruby_out
end

# do testing
# return a Hash ( at a minimum, return { status: result } )
def test(mod, add, rem)
#  test_results = nose(mod + add + rem)
  #  pylint_out = pylint(mod+add)
  test_results = ruby(mod, add, rem)

  git_results = git

  { status: test_results[:status],
    error: test_results[:stderr],
    stdout: test_results[:stdout],
    git: git_results[:stdout],
  }
end

