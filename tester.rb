require 'listen'
require 'json'
require_relative 'serial'
require_relative 'rg_logger'

class Tester < Serial
  include RGLogger

  attr_reader :results
  attr_accessor :logger
  
  def self.system_pipe3(pwd, cmd)
    values = nil

    Dir.chdir(pwd) do
      Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
        values = { :stdout => stdout.read, :stderr => stderr.read }
      end
    end

    return values
  end

  def initialize(paths, &block)
    super()
    @results = { status: :init }
    @test = (block_given?) ? block : nil
    @logger = nil

    @listener = Listen.to(*paths, ignore: /(^.?#|~$)/) do |mod, add, rem|
      test(mod, add, rem)
    end
    Thread.start { test([ '*' ]) }
    @listener.start
  end

  def result(serial = 0)
    wait_for_serial(serial)
    @results.merge({serial: value})
  end
  
  def test(modified, added=[], removed=[])
    @results = @test.call(modified, added, removed)
    inc
  rescue => detail
    @results = { status: :test_script_failed,
                 error: detail.backtrace.unshift(detail.message).join("\n") + "\npwd: #{@pwd}" }
  end
end
