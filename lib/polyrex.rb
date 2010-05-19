#!/usr/bin/ruby

# file: polyrex.rb

require 'polyrex-schema'
require 'backtrack-xpath'
require 'rexml/document'

class Polyrex
  include REXML

  def initialize(schema)

    @schema = schema

    @id = '1'
    a = @schema.split('/')
    @root_name = a[0]
        
    @doc = Document.new "<%s><summary/><records/></%s>" % ([@root_name] * 2)
    @parent_node = XPath.first(@doc.root,'records')

    @rpaths = (a.length).times.inject({}) {|r| r.merge ({a.join('/').gsub(/\[[^\]]+\]/,'') => a.pop}) }

    names = @rpaths.to_a[0..-2].map {|k,v| [v[/.[^\[]+/], k]}

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

  def to_xml()
    @doc.to_s
  end

end

