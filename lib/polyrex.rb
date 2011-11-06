#/usr/bin/ruby

# file: polyrex.rb

require 'polyrex-schema'
require 'line-tree'
require 'polyrex-objects'
require 'polyrex-createobject'
require 'ostruct'
require 'polyrex-object-methods'
require 'polyrex-xslt'
require 'rexle'

class Polyrex
  attr_accessor :summary_fields, :xslt_schema, :id_counter, :schema

  def initialize(location=nil, id_counter='1')

    @id_counter = id_counter
    
    if location then
      open(location)
      summary_h = Hash[*@doc.xpath("summary/*").map {|x| [x.name, x.text]}.flatten]      
      @summary = OpenStruct.new summary_h
      @summary_fields = summary_h.keys.map(&:to_sym)
    end
    
    @polyrex_xslt = PolyrexXSLT.new
  end

  def create(id=nil)
      # @create is a PolyrexCreateObject, @parent_node is a REXML::Element pointing to the current record
    
    @create.id = id || @id_counter
    @create.record = @parent_node.name == 'records' ? @parent_node : @parent_node.element('records')
    @create
  end

  def delete(id=nil)
    @doc.delete("//[@id='#{id}'")
  end

  def record()
    @parent_node
  end

  def to_xml(options={})
    refresh_summary
    @doc.to_s(options)
  end

  def save(filepath=nil)    
    refresh_summary
    filepath ||= @local_filepath
    @local_filepath = filepath
    File.open(filepath,'w'){|f| @doc.write f}    
  end  
  
  # -- start of crud methods -- 

  def find_by_id(id)
    @parent_node = @doc.element("//[@id='#{id}']")
  end

  def id(id)
    @parent_node = @doc.element("//[@id='#{id}']")
    self
  end

  # -- end of crud methods --
  
  # -- start of full text edit methods
  def format_masks
    @format_masks
  end 
  
  def parse(buffer='')
    buffer = yield if block_given?          
    string_parse buffer
    self
  end    
  
  def element(s)
    @doc.element(s)
  end
  
  def records
    @doc.xpath("records/*").map do |record|      
      @objects_a[0].new(record)
    end
  end

  def schema=(s)
    open s
    summary_h = Hash[*@doc.xpath("summary/*").map {|x| [x.name, x.text]}.flatten]      
    @summary = OpenStruct.new summary_h
    @summary_fields = summary_h.keys.map(&:to_sym)    
    self
  end
  
  def summary
    @summary
  end

  def to_a()
    recordx_map @doc.root
  end
  
  def to_xslt()    
    @polyrex_xslt.schema = @schema
    @polyrex_xslt.to_xslt
  end

  def xpath(s, &blk)

    if block_given? then
      @doc.xpath(s, &blk)
    else
      @doc.xpath s
    end
  end

  def xslt_schema(s)
    @polyrex_xslt.xslt_schema = s
    self
  end

  private

  def polyrex_new(schema)
    # -- required for the parsing feature
    doc = Rexle.new(PolyrexSchema.new(schema).to_s)
    @format_masks = doc.xpath('//format_mask/text()')
    schema_rpath = schema.gsub(/\[[^\]]+\]/,'')

    @recordx = schema_rpath.split('/')
    
    summary = ''
    if @format_masks.length == @recordx.length then
      root_format_mask = @format_masks.shift
      field_names = root_format_mask.to_s.scan(/\[!(\w+)\]/).flatten.map(&:to_sym)
      summary = field_names.map {|x| "<%s/>" % x}.join
    end
    
    summary << "<recordx_type>polyrex</recordx_type><schema>#{schema}</schema>"
    #----
    
    @schema = schema
    @id_counter = '0'

    root_name = @recordx.shift

    ("<%s><summary>%s</summary><records/></%s>" % [root_name, (summary || '') , root_name])
  end
  
  def recordx_map(node)
    # get the summary
    summary = XPath.first(node, 'summary')

    # get the fields
    fields = summary.elements.map do |x|
      next if %w(schema format_mask recordx_type).include? x.name 
      r = x.text.to_s.gsub(/^[\n\s]+/,'').length > 0 ? x.text : x.cdatas.join.strip
      REXML::Text::unnormalize(r)
    end

    # get the records
    records = XPath.first(node, 'records')
    a = records.elements.map {|x| recordx_map x}
    
    [fields, a]
  end
  
  def string_parse(lines)
    raw_header = lines.slice!(/<\?polyrex[^>]+>/)

    if raw_header then
      header = raw_header[/<?polyrex (.*)?>/,1]
      header.scan(/\w+\="[^"]+\"/).map{|x| r = x.split(/=/); \
             [(r[0] + "=").to_sym, r[1][/^"(.*)"$/,1]] }.each do |name, value|
                        self.method(name).call(value)
              end
    end

    format_line!(@parent_node, LineTree.new(lines.strip).to_a)
  end  
  
  def load_handlers(schema)
    @create = PolyrexCreateObject.new(schema, @id_counter)

    objects = PolyrexObjects.new(schema, @id_counter)    
    @objects = objects.to_h
    @objects_a = objects.to_a

    attach_create_handlers(@objects.keys)
    attach_edit_handlers(@objects)    
  end
  
  def format_line!(records, a, i=0)
    
    a.each do |x|    

      unless @recordx[i] then
        @recordx[i] = @recordx[-1].clone
        @format_masks[i] = @format_masks[-1]
      end

      tag_name = @recordx[i].to_s
      line = x.shift
      

      
      unless @format_masks[i][/^\(.*\)$/] then

        @field_names = @format_masks[i].to_s.scan(/\[!(\w+)\]/).flatten.map(&:to_sym)        

        t = regexify_fmask(@format_masks[i]) #.sub(/\[/,'\[').sub(/\]/,'\]')        

        a = t.reverse.split(/(?=\)[^\(]+\()/).reverse.map &:reverse
        patterns = tail_map(a)

        pattern = patterns.detect {|x| line.match(/#{x.join}/)}.join

        field_values = line.match(/#{pattern}/).captures      
        field_values += [''] * (@field_names.length - field_values.length)
      else

        format_masks = @format_masks[i][1..-2].split('|')
        patterns = format_masks.map do |x|
          regexify_fmask(x) #.sub(/\[/,'\[').sub(/\]/,'\]')
        end

        pattern = patterns.detect {|x| line.match(/#{x}/)}
        i = patterns.index(pattern)
        
        @field_names =  format_masks[i].to_s.scan(/\[!(\w+)\]/).flatten.map(&:to_sym)        
        
        field_values = line.match(/#{pattern}/).captures        
      end

      @id_counter.succ!

      record = Rexle::Element.new(tag_name)
      record.add_attribute(id: @id_counter.clone)
      summary = Rexle::Element.new('summary')
      
      @field_names.zip(field_values).each do |name, value|  
        field =  Rexle::Element.new(name.to_s)
        field.text = value
        summary.add field
      end

      summary.add Rexle::Element.new('format_mask').add_text(@format_masks[i])
      
      new_records = Rexle::Element.new('records')

      record.add summary
      record.add new_records
      records.add record
      
      format_line!(new_records, x, i+1) unless x.empty?
    end
  end
  
  # -- end of full text edit methods

  def attach_create_handlers(names)
    methodx = names.map do |name|
%Q(
  def create_#{name.downcase}(params) 
    self.create.#{name.downcase}
  end
)
    end

    self.instance_eval(methodx.join("\n"))
    
  end
  
  def attach_edit_handlers(objects)
    objects.keys.each do |name|
    self.instance_eval(
%Q(
  def #{name.downcase}()     
    @objects['#{name}'].new(@parent_node, @id)
  end
))
    end
    
  end
  
  def open(s)

    if s[/</] # xml
      buffer = s
    elsif s[/\[/] then  # schema
      buffer = polyrex_new s
    elsif s[/^https?:\/\//] then  # url
      buffer = Kernel.open(s, 'UserAgent' => 'Polyrex-Reader').read
    else # local file
      buffer = File.open(s,'r').read
      @local_filepath = s
    end

    @doc = Rexle.new buffer

    schema = @doc.root.text('summary/schema')
    
    unless @format_masks
      schema_rpath = schema.gsub(/\[[^\]]+\]/,'')
      @recordx = schema_rpath.split('/')
      @recordx.shift
    end
    
    id = @doc.xpath('max(//@id)')
    @id_counter = id.to_s.succ if id
    
    if schema then
      load_handlers(schema)
      load_find_by(schema)
    end

    @parent_node = @doc.element('records')

  end
  
  def regexify_fmask(f)

    a = f.split(/(?=\[!\w+\])/).map do |x|

      aa = x.split(/(?=[^\]]+$)/)

      if aa.length == 2 and aa.first[/\[!\w+\]/] then
        field, delimiter = *aa
        delimiter ||= '$'
        d = delimiter[0]
        "([^%s]+)%s" % ([d] * 2)
      else
        x.sub(/\[!\w+\]/,'(.*)')
      end
    end

    a.join            
  end
  
  def tail_map(a)
    [a] + (a.length > 1 ? tail_map(a[0..-2]) : [])
  end

  def load_find_by(schema)  
    a = PolyrexObjectMethods.new(schema).to_a

    methodx = a.map do |class_name, methods| 
      class_name.downcase!
      methods.map do |method_name| 
        xpath = %Q(@doc.element("//%s[summary/%s='\#\{val\}']")) % [class_name, method_name]
        "def find_by_%s_%s(val) @parent_node = %s;  self.%s end" % [class_name, method_name, xpath, class_name]
      end 
    end

    self.instance_eval methodx.join("\n")
  end

  def refresh_summary()
    @summary_fields.each do |x| 
      @doc.element('summary/' + x.to_s).text = @summary.method(x).call
    end
  end

end