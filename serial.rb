# this is for managing status change events for threads
class Serial
  def initialize()
    super()
    @value = 0
    @mutex = Mutex.new
    @cond = ConditionVariable.new
  end

  def ready
    ready = false
    @mutex.synchronize { ready = @value > 0 }
    return ready
  end

  def inc
    @mutex.synchronize do
      @value += 1
      @cond.broadcast()
    end
  end

  def value
    v = nil
    @mutex.synchronize { v = @value }
    return v
  end

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

  def to_s; value.to_s end
end

