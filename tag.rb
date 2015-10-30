class Tag
  def result; return @result__ end

  def self.strip(*args)
    translations={ :amp => '&', :quot => '"', :apos => "'", :lt => "<", :gt => ">" }
    args.map { |a|
      b = a.to_s.dup
      translations.each { |k,v| b.gsub!(/#{v}/,"&#{k};") }
      b
    }.join('')
  end

  def initialize(&block)
    @parent__ = [[]]
    @context__ = eval("self", block.binding)
    instance_eval &block
    @selector__ = []
    @result__ = @parent__.pop.join
  end

  def append(*args) @parent__.last.push( args.join ); nil end

  def css(name, *args)
    attribs = []
    def make_attrib(arg) (arg.class == Hash) ? arg.map { |k,v| k = k.to_s.gsub(/_/,'-'); (v.length > 0) ? "#{k}:#{v}" : k } : [ arg.to_s ] end

    if name.class == Hash then
      return '"' + make_attrib(name).join(';') + '"'
    else
      name = name.to_s
      name[0] = '.' if name[0] == '_'

      args.each { |arg| attribs += make_attrib(arg) }
      attribs += make_attrib(yield(name)) if block_given?
    
      append( name, '{', attribs.join(';') + ';', '}' )
    end
  end
  
  def tag(name, value, *args)
    end_tag_always = [ :script ]
    attribs = []
    args.each do |arg|
      if arg.class == Hash then
        arg.each_pair do |k,v|
          key = (k.class == Symbol) ? k.to_s.gsub(/_/,'-') : k
          attribs.push([key, '="', v.to_s.gsub(/"/,''), '"'].join)
        end
      end
    end
    if value.length > 0 or end_tag_always.include?(name) then
      append( attribs.unshift("<#{name}").join(' '), '>', "\n", value, "\n", "</#{name}>", "\n" )
    else
      append( attribs.unshift("<#{name}").join(' '), '/>', "\n" )
    end
  end
  
  def text(&block) append(Tag.strip(yield)) end

  def p(*args, &block) tag('p', [yield].flatten.join, *args) end

  def method_missing(name, *args, &block)
    if @context__ and @context__.respond_to?(name) then
      return @context__.send(name, *args, &block)
    else
      @parent__.push([])
      append([yield(name)].flatten.join(' ')) if block_given?
      tag(name, @parent__.pop.join, *args)
    end
  end
end

