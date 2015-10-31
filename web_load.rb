# load a web page on most systems

class WebLoad
  def self.page(url)
    cmd = case RbConfig::CONFIG['host_os']
          when /mswin|mingw|cygwin/; "start"
          when /darwin/;             "open"
          when /linux|bsd/;          "xdg-open"
          end
    system "#{cmd} #{url}"
  end
end
