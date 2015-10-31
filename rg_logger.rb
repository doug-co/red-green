# this is a mixin which is meant to add simple logging facilities to a class

module RGLogger
  def set_logger(&block)
    self.logger = block if block_given?
  end

  def log(msg)
    self.logger.call(msg) if self.logger
  end
end
