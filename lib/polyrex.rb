#/usr/bin/ruby

# file: polyrex.rb

require 'polyrex-schema'
require 'line-tree'
require 'polyrex-objects'
require 'polyrex-createobject'
require 'ostruct'
require 'polyrex-object-methods'
require 'rexle'

class Polyrex

  def initialize(location)
    @id = '0'
    open(location)    
  end

  def create(id=nil)
    # @create is a PolyrexCreateObject, @parent_node is a REXML::Element pointing to the current record
    @create.id = (id || @id.succ!)

    @create.record = @parent_node.name == 'records' ? @parent_node : @parent_node.element('records')
    @create
  end

  def delete(id=nil)
    @doc.delete("//[@id='#{id}'")
  end

  def record()
    @parent_node
  end

  def to_xml()
    @doc.to_s
  end

  def save(filepath)    
    File.open(filepath,'w'){|f| @doc.write f}    
  end  
  
  # -- start of crud methods -- 

  def find_by_id(id)
    @parent_node = @doc.element("//[@id='#{id}']")
    self
  end

  alias id find_by_id
  # -- end of crud methods --
  
  # -- start of full text edit methods
  def format_masks
    @format_masks
  end 

  def parse(lines)
    format_line!(@parent_node, LineTree.new(lines).to_a)
    self
  end
  
  def element(s)
    @doc.element(s)
  end

  def xpath(s, &blk)

    if block_given? then
      @doc.xpath(s, &blk)
    else
      @doc.xpath s
    end
  end
  
  def records
    @doc.xpath("records/*").map do |record|      
      @objects_a[0].new(record, @id)
    end
  end
  
  def summary
    OpenStruct.new Hash[*@doc.xpath("summary/*").map {|x| [x.name, x.text]}.flatten]
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
    @id = '0'

    root_name = @recordx.shift

    ("<%s><summary>%s</summary><records/></%s>" % [root_name, (summary || '') , root_name])
  end
  
  def load_handlers(schema)
    @create = PolyrexCreateObject.new(schema, @id)
    objects = PolyrexObjects.new(schema)    
    @objects = objects.to_h
    @objects_a = objects.to_a
    attach_create_handlers(@objects.keys)
    attach_edit_handlers(@objects)    
  end
  
  def format_line!(records, a, i=0)
    
    a.each do |x|    
      
      tag_name = @recordx[i].to_s      
      line = x.shift
      
      @field_names = @format_masks[i].to_s.scan(/\[!(\w+)\]/).flatten.map(&:to_sym)
      t = @format_masks[i].to_s.gsub(/\[!(\w+)\]/, '(.*)').sub(/\[/,'\[').sub(/\]/,'\]')
      a = t.reverse.split(/(?=\)\*\.\()/).reverse.map &:reverse

      patterns = tail_map(a)
      pattern = patterns.detect {|x| line.match(/#{x.join}/)}.join
      field_values = line.match(/#{pattern}/).captures      
      field_values += [''] * (@field_names.length - field_values.length)

      @id.succ!

      record = Rexle::Element.new(tag_name)
      record.add_attribute('id' => @id.clone)
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
    @objects['#{name}'].new(@parent_node)
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
    end

    @doc = Rexle.new buffer

    schema = @doc.root.text('summary/schema')
    
    unless @format_masks
      schema_rpath = schema.gsub(/\[[^\]]+\]/,'')
      @recordx = schema_rpath.split('/')
      @recordx.shift
    end
    
    id = @doc.xpath('max(//@id)')
    @id = id.to_s.succ if id
    
    load_handlers(schema)
    load_find_by(schema)

    @parent_node = @doc.element('records')

  end
  
  def tail_map(a)
    [a] + (a.length > 1 ? tail_map(a[0..-2]) : [])
  end

  def load_find_by(schema)  
    a = PolyrexObjectMethods.new(schema).to_a

    methodx = a.map do |class_name, methods| 
      class_name.downcase!
      methods.map do |method_name| 
        xpath = %Q(@doc.xpath("//%s[summary/%s='\#\{val\}']")) % [class_name, method_name]
        "def find_by_%s_%s(val) @parent_node = %s;  self.%s end" % [class_name, method_name, xpath, class_name]
      end 
    end

    self.instance_eval methodx.join("\n")
  end
  
end