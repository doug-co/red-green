# this is a mixin which adds a simple logging facility to a class

module RGLogger
  def set_logger(&block)
    @logger = block if block_given?
  end

  def logger; @logger end

  def log(msg)
    self.logger.call(msg) if self.logger
  end
end
