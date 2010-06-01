#/usr/bin/ruby

# file: polyrex.rb

require 'polyrex-schema'
require 'line-tree'
require 'polyrex-objects'
require 'polyrex-createobject'
require 'rexml/document'

class Polyrex
  include REXML

  def initialize(location)
    open(location)    
  end

  def create()
    @create.id = @id
    @create.record = @parent_node
    @create
  end

  def delete(id=nil)
    self.find_by_id(id) if id
    @parent_node.parent.delete @parent_node
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
    @parent_node = XPath.first(@doc.root, "//[@id='#{id}']")
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
  
  def xpath(s)
    XPath.first(@doc.root, s)
  end

  private

  def polyrex_new(schema)
    # -- required for the parsing feature
    doc = Document.new(PolyrexSchema.new(schema).to_s)
    @format_masks = XPath.match(doc.root, '//format_mask/text()').map &:to_s
    schema_rpath = schema.gsub(/\[[^\]]+\]/,'')
    @recordx = schema_rpath.split('/')
    
    summary = ''
    if @format_masks.length == @recordx.length then
      root_format_mask = @format_masks.shift 
      field_names = root_format_mask.to_s.scan(/\[!(\w+)\]/).flatten.map(&:to_sym)
      summary = field_names.map {|x| "<%s/>" % x}.join
    end
    
    summary << "<schema>#{schema}</schema>"
    #----
    
    @schema = schema
    @id = '0'

    root_name = @recordx.shift

    ("<%s><summary>%s</summary><records/></%s>" % [root_name, (summary || '') , root_name])
  end
  
  def load_handlers(schema)
    @create = PolyrexCreateObject.new(schema)
    @objects = PolyrexObjects.new(schema).to_h
    attach_create_handlers(@objects.keys)
    attach_edit_handlers(@objects)    
  end
  
  def format_line!(records, a, i=0)
    
    a.each do |x|    
      
      tag_name = @recordx[i].to_s      
      line = x.shift.join
      
      @field_names = @format_masks[i].to_s.scan(/\[!(\w+)\]/).flatten.map(&:to_sym)
      t = @format_masks[i].to_s.gsub(/\[!(\w+)\]/, '(.*)').sub(/\[/,'\[').sub(/\]/,'\]')
      field_values = line.match(/#{t}/).captures      

      @id = (@id.to_i + 1).to_s      
      record = Element.new(tag_name)
      record.add_attribute('id', @id)
      summary = Element.new('summary')
      
      @field_names.zip(field_values).each do |name, value|  
        field =  Element.new(name.to_s)
        field.text = value
        summary.add field
      end
      summary.add Element.new('format_mask').add_text(@format_masks[i])
      
      new_records = Element.new('records')

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
  def create_#{name}(params) 
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
    if s[/\[/] then  # schema
      buffer = polyrex_new s
    elsif s[/^https?:\/\//] then  # url
      buffer = Kernel.open(s, 'UserAgent' => 'Polyrex-Reader').read
    elsif s[/\</] # xml
      buffer = s
    else # local file
      buffer = File.open(s,'r').read
    end

    puts '*' + buffer + '*'
    @doc = Document.new buffer
    @id = XPath.match(@doc.root, '//@id').map{|x| x.value.to_i}.max.to_i + 1
    
    schema = @doc.root.text('summary/schema')
    #puts 'schema : ' + schema
    load_handlers(schema)
    @parent_node = XPath.first(@doc.root,'records')    

  end    
  
end
