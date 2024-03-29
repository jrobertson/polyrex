#!/usr/bin/env ruby

# file: polyrex.rb

#require 'open-uri'
#require 'polyrex-schema'
#require 'line-tree'
require 'polyrex-objects'
#require 'polyrex-createobject'
require 'polyrex-object-methods'
require 'recordx-xslt'
#require 'rexle'
#require 'recordx'
#require 'rxraw-lineparser'
#require 'yaml'
require 'dynarex'

module Enumerable
  def repeated_permutation(size, &blk)
    f = proc do |memo, &blk|
      if memo.size == size
        blk.call memo
      else
        self.each do |i|
          f.call memo + [i], &blk
        end
      end
    end

    if block_given?
      f.call [], &blk
    else
      Enumerator.new(f, :call, [])
    end
  end
end

class PolyrexException < Exception
end

class Polyrex
  include RXFReadWriteModule

  attr_accessor :summary_fields, :xslt_schema, :id_counter, 
                :schema, :type, :delimiter, :xslt, :format_masks

  def initialize(location=nil, schema: nil, id_counter: '1',
                 delimiter: '', debug: false)

    @id_counter, @debug = id_counter, debug
    @format_masks = []

    self.method(:schema=).call(schema) if schema  
    
    if location then      

      s, type = RXFReader.read(location)
      return import(s) if s =~ /^\<\?polyrex\b/
      
      @local_filepath = location if type == :file or type == :dfs

      openx(s)
      puts 'before schema' if @debug
      if schema then

        fields = @schema[/\/.*/].scan(/\[([^\]]+)/).map \
          {|x| x.first.split(',').map(&:strip)}
        refresh_records self.records, fields, 0

      end

      @summary = RecordX.new @doc.root.xpath("summary/*")
      @summary_fields = @summary.keys
      

    end
    
    @polyrex_xslt = RecordxXSLT.new
    #@parent_node = @doc.root if @doc

    set_delimiter(delimiter)
  end

  def add(pxobj)
    self.record.add pxobj.node
  end

  def content(options={})
    CGI.unescapeHTML(to_xml(options))
  end

  def create(id: @id_counter)
    puts 'id: ' + id.inspect if @debug
    @create = PolyrexCreateObject.new(id: id, record: @doc.root)
  end

  def delete(x=nil)

    if x.to_i.to_s  == x.to_s then
      @doc.root.delete("//[@id='#{x}'")
    else
      @doc.root.xpath(x).each(&:delete)
    end
  end
  
  def delimiter=(separator)

    @delimiter = separator

    @format_masks.map! do |format_mask|
      format_mask.to_s.gsub(/\s/, separator)
    end
  end  

  alias set_delimiter delimiter=
  
  def each_recursive(parent=self, level=0, &blk)
    
    parent.records.each.with_index do |x, index|

      blk.call(x, parent, level, index) if block_given?

      each_recursive(x, level+1, &blk) if x.records.any?
      
    end
    
  end

  def export(filepath)
    FileX.write filepath, to_s()
  end

  def record()
    @parent_node
  end

  def to_xml(options={})
    refresh_summary
    @doc.to_s(options)
  end

  def save(filepath=nil, opt={}, options: opt, pretty: false)    
    
    refresh_summary
    filepath ||= @local_filepath
    @local_filepath = filepath
    
    options.merge!({pretty: pretty}) if options.empty?
    xml = @doc.to_s(options)
    
    buffer = block_given? ? yield(xml) : xml
    FileX.write filepath, buffer
  end
  
  # -- start of crud methods -- 

  def find_by_id(id)
    
    puts 'inside find_by_id: ' + id if @debug
    #return @doc if @debug
    @parent_node = @doc.root.element("//[@id='#{id}']")
    @objects[@parent_node.name.to_sym].new(@parent_node, id: @id)
    
  end

  def id(id)
    @parent_node = @doc.root.element("//[@id='#{id}']")
    self
  end
  
  def order=(val)
    @order = val.to_s
  end

  # -- end of crud methods --
  
  # -- start of full text edit methods
  def format_masks
    @format_masks
  end 
  
  def parse(x=nil, options={})

    buffer, type = RXFReader.read(x)
    
    if type == :unknown and buffer.lines.length <= 1 then
      raise PolyrexException, 'File not found: ' + x.inspect
    end
    
    buffer = yield if block_given?          
    string_parse buffer.clone, options

    self
  end    
  
  alias import parse

  def element(s)
    @doc.root.element(s)
  end
  
  def leaf_nodes_to_dx()
    
    schema, record_name = @summary.schema\
                                .match(/([^\/]+\/([^\/]+)\[[^\[]+$)/).captures
    
    xml = RexleBuilder.new

    xml.items do
      xml.summary do
        xml.schema schema.sub(/(\/\w+)\[([^\]]+)\]/,'\1(\2)')
      end
      xml.records 
    end
    
    doc = Rexle.new xml.to_a
    body = doc.root.element 'records'
    a = self.xpath('//' + record_name)

    a.each do |record|
      body.add record.deep_clone
    end

    make_dynarex doc.root
  end
  
  def records

    @doc.root.xpath("records/*").map do |node|      
      Kernel.const_get(node.name.capitalize).new node, id: @id_counter
    end
    
  end

  def rxpath(s)
    
    a = @doc.root.xpath s.split('/').map \
                  {|x| x.sub('[','[summary/').prepend('records/')}.join('/')
    
    a.map do |node| 
      Kernel.const_get(node.name.capitalize).new node, id: node.attributes[:id]
    end

  end
  
  def schema=(s)

    if s =~ /gem\[/ then
      raise PolyrexException, "invalid schema: cannot contain the " + 
          "word gem as a record name"
    end
    
    openx(s)

    summary_h = Hash[*@doc.root.xpath("summary/*").\
                                     map {|x| [x.name, x.text.to_s]}.flatten]

    @summary = RecordX.new summary_h
    @summary_fields = summary_h.keys.map(&:to_sym)    
    self
  end
  
  def summary
    @summary
  end

  def to_a()
    recordx_map @doc.root
  end
  
  def to_dynarex()

    root = @doc.root.deep_clone

    summary = root.element('summary')
    #summary.delete('format_mask')
    #summary.element('recordx_type').text = 'dynarex'

    summary.add root.element('records/*/summary/format_mask').clone    
    e = summary.element('schema')
    e.text = e.text[/[^\/]+\/[^\/]+/].sub(/(\/\w+)\[([^\]]+)\]/,'\1(\2)')

    make_dynarex(root)
  end
  
  def to_opml()
    
    puts '@schema: ' + @schema.inspect if @debug
    
    head, body = @schema.split(/(?<=\])/,2)
    schema_body = body.gsub(/(?<=\[)[^\]]+/) do |x|
      x.split(/\s*,\s*/).map {|field| '@' + field + ':' + field}.join(', ')
    end
    schema_head = head.gsub(/(?<=\[)[^\]]+/) do |x|
      x.split(/\s*,\s*/).map {|field| field + ':' + field}.join(', ')
    end

    puts 'schema_body: ' + schema_body.inspect if @debug
    puts 'schema_head: ' + schema_head.inspect if @debug
    xslt_schema = schema_head.sub(/^\w+/,'opml>head') + 
        schema_body.gsub(/\w+(?=\[)/,'outline')\
        .sub(/\/(\w+)(?=\[)/,'/body>outline')
        
    puts 'xslt_schema: ' + xslt_schema.inspect if @debug
    
    recxslt = RecordxXSLT.new(schema: @schema, xslt_schema: xslt_schema)
    
    Rexslt.new(recxslt.to_xslt, self.to_xml).to_s    
    
  end

  def to_s(header: true)

    def build(records, indent=0)

      records.map do |item|

        summary = item.element 'summary'
        format_mask = summary.text('format_mask').to_s
        line = format_mask.gsub(/\[![^\]]+\]/){|x| summary.text(x[2..-2]).to_s}
        puts 'line: ' + line.inspect if @debug

        recordsx = item.element('records').elements.to_a
        
        if recordsx.length > 0 then
          line = line + "\n" + build(recordsx, indent + 1).join("\n") 
        end
        ('  ' * indent) + line
      end
    end

    sumry = ''


    summary_fields = self.summary.to_h.keys

    %w(recordx_type schema format_mask).each {|x| summary_fields.delete x}
    sumry = summary_fields.map {|x| x.to_s + ': ' + \
                       self.summary.method(x.to_sym).call}.join("\n") + "\n"


    if @raw_header then
      declaration = @raw_header
    else

      smry_fields = %i(schema)              
      if self.delimiter.length > 0 then
        smry_fields << :delimiter 
      else
        smry_fields << :format_mask
      end

      s = smry_fields.map {|x|  "%s=\"%s\"" % \
        [x, self.summary.send(x).to_s.gsub('"', '\"') ]}.join ' '

      declaration = %Q(<?polyrex %s?>\n) % s
    end

    docheader = declaration + "\n" + sumry
    out = build(self.records).join("\n")
    header ? docheader + "\n" + out : out
    
  end
  
  def to_tree()
    
    s = @schema.gsub(/(?<=\[)[^\]]+/) do |x|
      x.split(/\s*,\s*/).map {|field| '@' + field + ':' + field}.join(', ')
    end

    xslt_schema = s.gsub(/\w+(?=\[)/,'item').sub(/^\w+/,'tree')                    
    recxslt = RecordxXSLT.new(schema: @schema, xslt_schema: xslt_schema)    
    Rexslt.new(recxslt.to_xslt, self.to_xml).to_s        
    
  end  

  def to_xslt()    
    @polyrex_xslt.schema = @schema
    @polyrex_xslt.to_xslt
  end

  def xpath(s, &blk)

    if block_given? then
      @doc.root.xpath(s, &blk)
    else
      @doc.root.xpath s
    end
  end

  def xslt=(value)
    
    @summary.xslt = value

  end    
  
  def xslt_schema=(s)
    @polyrex_xslt.xslt_schema = s
    self
  end
  
  protected
  
  def doc()
    @doc
  end

  private
  
  def make_dynarex(root)
    
    root.delete('summary/recordx_type')
    root.delete('summary/format_mask')
    root.xpath('records/*/summary/format_mask').each(&:delete)
    root.xpath('records/*/records').each(&:delete)


xsl_buffer = '
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output encoding="UTF-8"
            indent="yes"
            omit-xml-declaration="yes"/>

  <xsl:template match="*">
    <xsl:element name="{name()}">
    <xsl:element name="summary">
      <xsl:for-each select="summary/*">
        <xsl:copy-of select="."/>
      </xsl:for-each>
    </xsl:element>
    <xsl:element name="records">
      <xsl:for-each select="records/*">
        <xsl:element name="{name()}">
          <xsl:copy-of select="summary/*"/>
        </xsl:element>
      </xsl:for-each>
    </xsl:element>
    </xsl:element>
  </xsl:template>
</xsl:stylesheet>
'

    buffer = Rexslt.new(xsl_buffer, root.xml).to_s
    Dynarex.new buffer
    
  end    

  def refresh_records(records, fields, level)

    records.each do |record|

      level -= 1 unless fields[level]
      fields[level].each {|x| record.method(x).call }

      if record.records.any? then
        refresh_records record.records, fields, level+1
      end
    end

  end

  def polyrex_new(schema)

    # -- required for the parsing feature
    doc = PolyrexSchema.new(schema).to_doc
    fm = doc.root.xpath('//format_mask/text()')

    @format_masks = fm.zip(@format_masks).map{|x,y| y || x }

    schema_rpath = schema.gsub(/\[[^\]]+\]/,'')

    @recordx = schema_rpath.split('/')

    summary = ''
    if @format_masks.length == @recordx.length then
      root_format_mask = @format_masks.shift
      field_names = root_format_mask.to_s.scan(/\[!(\w+)\]/).\
                                                          flatten.map(&:to_sym)
      summary = field_names.map {|x| "<%s/>" % x}.join
    end
    
    summary << "<recordx_type>polyrex</recordx_type><schema>#{schema}</schema>"
    #----
    
    @schema = schema
    @id_counter = '0'

    root_name = @recordx.shift
    ("<%s><summary>%s</summary><records/></%s>" % \
                                    [root_name, (summary || '') , root_name])

  end
  
  def recordx_map(node)
    
    # get the summary
    fields = node.xpath('summary/*').map do |x|
      next if %w(schema format_mask recordx_type).include? x.name 
      r = x.text.to_s.gsub(/^[\n\s]+/,'').length > 0 ? x.text.to_s : \
                                                          x.cdatas.join.strip
      r
    end

    # get the records
    a = node.xpath('records/*').map {|x| recordx_map x}
    
    [fields.compact, a]
  end  
  
  def string_parse(buffer, options={})

    @raw_header = buffer.slice!(/<\?polyrex[^>]+>/)
    
    if @raw_header then
      header = @raw_header[/<?polyrex (.*)?>/,1]

      r1 = /([\w\[\]\-]+\s*\=\s*'[^']*)'/
      r2 = /([\w\[\]\-]+\s*\=\s*"[^"]*)"/

      a = header.scan(/#{r1}|#{r2}/).map(&:compact).flatten            

      
      a.each do |x|
        
        attr, val = x.split(/\s*=\s*["']/,2)

        i = attr[/format_masks?\[(\d+)/,1]        

        if i then

          @format_masks[i.to_i] = val

        else
          unless options.keys.include? attr[0..-2].to_sym then
            self.method((attr + '=').to_sym).call(unescape val)
          end
        end
      end
      
      options.each do |k,v|
        
        if options[k] then
          a.delete a.assoc(k)
          self.method(((k.to_s) + '=').to_sym).call(options[k])
        end
        
      end
            
    end

    raw_lines = buffer.lstrip.lines.map(&:chomp)

    raw_summary = schema[/^\w+\[([^\]]+)/,1]

    if raw_summary then
      a_summary = raw_summary.split(',').map(&:strip)

      while raw_lines.first[/#{a_summary.join('|')}:\s+\w+/] do      

        label, val = raw_lines.shift.match(/(\w+):\s+([^$]+)$/).captures              
        @summary.send((label + '=').to_sym, val)
      end

    end

    @summary.format_mask = @format_masks

    records = @parent_node.root
    @parent_node = records.parent
    records.delete

    puts 'raw_lines: ' + raw_lines.inspect if @debug
    lines = LineTree.new(raw_lines.join("\n"), ignore_label: true).to_a
    puts 'lines: ' + lines.inspect if @debug
    @parent_node.root.add format_line!( lines)

  end  
  
  def unescape(s)
    r = s.gsub('&lt;', '<').gsub('&gt;','>')
  end
  
  def load_handlers(schema)

    objects = PolyrexObjects.new(schema, debug: @debug)    
    h = objects.to_h
    puts 'h:  ' + h.inspect if @debug
    @objects = h.inject({}){|r,x| r.merge x[0].downcase => x[-1]}

    @objects_a = objects.to_a
    attach_create_handlers(@objects.keys)
    #attach_edit_handlers(@objects)    

  end
  
  def format_line!(a, i=0)

    records = Rexle::Element.new('records')
    
    # add code here for rowx
    @field_names =  format_masks[i].to_s.scan(/\[!(\w+)\]/)\
                                            .flatten.map(&:to_sym)

    rowx_fields = a.map{|x| x.first[/^\w+(?=:)/].to_s.to_sym}.uniq
    
    records = if (@field_names & rowx_fields).length >= 2 then
      # rowx implementation still to-do
      #vertical_fiedlparse(records, a, i)
    else
      horizontal_fieldparse(records, a, i)
    end
    
  end
    
  
  # -- end of full text edit methods
    
  def horizontal_fieldparse(records, a, i)

    a.each do |x|          

      unless @recordx[i] then
        @recordx[i] = @recordx[-1].clone
        @format_masks[i] = @format_masks[-1]
      end

      tag_name = @recordx[i].to_s
      line = raw_line = x.shift


      line = raw_line
      
      if line[/\w+\s*---/] then

        node_name = line.sub(/\s*---/,'')
        ynode = Rexle::Element.new(node_name).add_text("---\n" + x.join("\n"))
        
        summary.add ynode
        next
      end
      
      puts '@schema: ' + @schema.inspect if @debug
      schema_a = @schema.split('/')[1..-1]
      
      if @debug then
        puts 'schema_a: ' + schema_a.inspect
        puts 'i: ' + i.inspect
      end
      
      unless @format_masks[i][/^\(.*\)$/] then

        @field_names, field_values = RXRawLineParser.new(format_masks[i])\
                                                            .parse(line)  

        @field_names = schema_a[i] ? \
            schema_a[i][/\[([^\]]+)/,1].split(/\s*,\s*/).map(&:to_sym) : \
            schema_a[-1][/\[([^\]]+)/,1].split(/\s*,\s*/).map(&:to_sym)

      else

        format_masks = @format_masks[i][1..-2].split('|')
        patterns = format_masks.map do |x|
          regexify_fmask(x)
        end

        pattern = patterns.detect {|x| line.match(/#{x}/)}
        i = patterns.index(pattern)
        
        @field_names =  format_masks[i].to_s.scan(/\[!(\w+)\]/)\
                                              .flatten.map(&:to_sym)

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

      format_mask = @format_masks[i].to_s

      index = i >= schema_a.length ? schema_a.length - 1 : i

      schema = schema_a[index..-1].join('/')
      summary.add Rexle::Element.new('format_mask').add_text(format_mask)
      summary.add Rexle::Element.new('schema').add_text(schema)
      summary.add Rexle::Element.new('recordx_type').add_text('polyrex')
      
      record.add summary
      child_records = format_line!(x, i+1)

      record.add child_records
      records.add record
    end
    
    records
  end

  def attach_create_handlers(names)
    methodx = names.map do |name|
%Q(
  def create_#{name.downcase}(params, &blk) 
    self.create.#{name.downcase}(params, &blk)
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
    @objects['#{name}'].new(@parent_node, id: @id)
  end
))
    end
    
  end
  
  def openx(s)

    puts 'inside openx' if @debug

    if s[/</] # xml
      buffer = s
    elsif s[/\[/] then  # schema
      buffer = polyrex_new s
    elsif s[/^https?:\/\//] then  # url
      buffer = URI.open(s, 'UserAgent' => 'Polyrex-Reader').read
    else # local file
      buffer = FileX.read s
      @local_filepath = s
    end

    buffer.gsub!(/<schema>[^<]+/, '<schema>' + @schema) if @schema
    @doc = Rexle.new buffer

    schema = @doc.root.text('summary/schema').to_s
    
    if schema.nil? then
      schema = PolyrexSchema.new.parse(buffer).to_schema 
      e = @doc.root.element('summary')
      e.add Rexle::Element.new('schema').add_text(schema)
    end

    unless @format_masks
      schema_rpath = schema.gsub(/\[[^\]]+\]/,'')

      @recordx = schema_rpath.split('/')
      @recordx.shift
    end

    id = @doc.root.xpath('max(//@id)')
    @id_counter = id.to_s.succ if id

    if schema then
      load_handlers(schema)
      load_find_by(schema) unless schema[/^\w+[^\/]+\/\{/]
    end

    @parent_node = @doc.root.element('records')

  end
      
  def regexify_fmask(f)

    a = f.split(/(?=\[!\w+\])/).map do |x|

      aa = x.split(/(?=[^\]]+$)/)

      if aa.length == 2 and aa.first[/\[!\w+\]/] then
        field, delimiter = *aa
        delimiter ||= '$'
        d = delimiter[0]
        "('[^']+'|[^%s]+)%s" % ([d] * 2)
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
        
        xpath = %Q(@doc.root.element("//%s[summary/%s='\#\{val\}']")) % \
                                                      [class_name, method_name]
        xpath2 = %Q(@doc.root.xpath("//%s[summary/%s='\#\{val\}']")) % \
                                                      [class_name, method_name]
        
        "def find_by_#{class_name}_#{method_name}(val) 
        
          node = #{xpath}
          
          if node then
            Kernel.const_get(node.name.capitalize).new node, id: @id
          else
            nil
          end
          
        end

        def find_all_by_#{class_name}_#{method_name}(val) 
        
          nodes = #{xpath2}
          
          if nodes then
            nodes.map do |node|
              Kernel.const_get(node.name.capitalize).new node, id: @id
            end
          else
            nil
          end
          
        end        
        "
      end 
    end

    self.instance_eval methodx.join("\n")
  end


  # refreshes the XML document with any new modification from 
  #                                                the summary object
  def refresh_summary()
    
    summary = @doc.root.element('summary')    
    @summary.to_h.each do |k,v|
      
      puts "k: %s; v: %s" % [k, v] if @debug
      e = summary.element(k.to_s)
      if e then
        e.text = v
      else
        summary.add Rexle::Element.new(k.to_s).add_text(v)        
      end
    end
    
    if @summary.xslt then
      @doc.instructions = [['xml-stylesheet', 
        "title='XSL_formatting' type='text/xsl' href='#{@summary.xslt}'"]] 
    end
  end

end
