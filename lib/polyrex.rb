#/usr/bin/ruby

# file: polyrex.rb

require 'polyrex-schema'
require 'backtrack-xpath'
require 'line-tree'
require 'rexml/document'

class Polyrex
  include REXML

  def initialize(schema)
    
    # -- required for the parsing feature
    doc = Document.new(PolyrexSchema.new(schema).to_s)
    @format_masks = XPath.match(doc.root, '//format_mask/text()').map &:to_s
    schema_rpath = schema.gsub(/\[[^\]]+\]/,'')
    @recordx = schema_rpath.split('/')
    
    if @format_masks.length == @recordx.length then
      root_format_mask = @format_masks.shift 
      field_names = root_format_mask.to_s.scan(/\[!(\w+)\]/).flatten.map(&:to_sym)
      summary = field_names.map {|x| "<%s/>" % x}.join
    end
    #----
    
    @schema = schema

    @id = '0'
    a = @schema.split('/')        

    @rpaths = (a.length).times.inject({}) {|r| r.merge ({a.join('/').gsub(/\[[^\]]+\]/,'') => a.pop}) }

    names = @rpaths.to_a[0..-2].map {|k,v| [v[/[^\[]+/], k]}
    attach_create_handlers(names)

    @root_name = @recordx.shift

    @doc = Document.new("<%s><summary>%s</summary><records/></%s>" % [@root_name, (summary || '') , @root_name])
    @parent_node = XPath.first(@doc.root,'records')
    
  end

  def attach_create_handlers(names)
    names[0..-2].each do |name, xpath|
    self.instance_eval(
%Q(
  def create_#{name}(params) 
    create_node(@parent_node, @rpaths['#{xpath}'], params)
    self
  end
))
    end

    name, xpath = names[-1]
    self.instance_eval(
%Q(
def create_#{name}(params)
  
  @parent_node = XPath.first(@doc.root,'records')
  record = create_node(@parent_node, @rpaths['#{xpath}'], params)
  @parent_node = XPath.first(record.root, 'records')
  self
end
))
    
  end
  
  # -- start of crud methods --
  def valid_creation?()

    xpath = BacktrackXPath.new(@parent_node).to_s.gsub('//','/')
    path = xpath_to_rpath(xpath).sub(/\/?records$/,'')
    rpath = @root_name + (path.length > 0 ? '/' + path : path)

    schema_rpath = @schema.gsub(/\[[^\]]+\]/,'') 
    local_path = (schema_rpath.split('/') - rpath.split('/')).join('/')
    child_rpath = rpath + '/' + local_path

    @rpaths.has_key? child_rpath
  end

  def create_node(parent_node, child_schema, params)
    raise "create_node error: can't create record" unless valid_creation?
    record = Document.new PolyrexSchema.new(child_schema).to_s
    record.root.add_attribute('id', @id)
    @id = (@id.to_i + 1).to_s

    a = child_schema[/[^\[]+(?=\])/].split(',')
    a.each do |field_name|  
      field = XPath.first(record.root, 'summary/' + field_name)
      field.text = params[field_name.to_sym]
    end

    parent_node.add record    
    record
  end

  def xpath_to_rpath(xpath)
    xpath.split('/').each_slice(2).map(&:last).join('/').gsub(/\[[^\]]+\]/,'')
  end

  def find_by_id(id)
    @parent_node = XPath.first(@doc.root, "//[@id='#{id}']")
    self
  end
  # -- end of crud methods --
  
  # -- start of full text edit methods
  def format_masks
    @format_masks
  end 

  def parse(lines)
    format_line!(@parent_node, LineTree.new(lines).to_a)
    self
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

  def to_xml()
    @doc.to_s
  end

  def save(filepath)    
    File.open(filepath,'w'){|f| @doc.write f}    
  end  

end
