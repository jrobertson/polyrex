#!/usr/bin/ruby

# file: test_polyrex.rb
 
require '/home/james/learning/ruby/testdata'
require 'polyrex'
#require '/home/james/learning/ruby/polyrex'
require 'pretty-xml'
include PrettyXML

puts 'file : ' + __FILE__
testdata = Testdata.new('testdata_polyrex.xml')

testdata.paths do |path|

  path.tested? 'Creating a new document from a schema' do 

    def path.test(schema) 
      write Polyrex.new(schema).to_xml
    end

  end

  path.tested? 'Creating a new document from xml' do

    def path.test(xml) 
      write Polyrex.new(xml).to_xml
    end

  end

  path.tested? 'Creating a new record' do

    def path.test(schema, title)
      polyrex = Polyrex.new(schema)
      polyrex.create.posts(title: title)
      write polyrex.to_xml
    end

  end


  path.tested? 'Creating a new record with a block' do

    def path.test(schema, title, title2, title3)

      polyrex = Polyrex.new(schema)

      polyrex.create.posts(title: title) do |create|
        create.entry title: title2
        create.entry title: title3
      end

      write polyrex.to_xml
    end

  end


  path.tested? 'Parsing a document' do 

    def path.test(schema, lines)

      entities = Polyrex.new(schema)
      entities.parse(lines)
      write entities.to_xml
    end

  end

  path.tested? 'creating a record from an id' do

    def path.test(schema, lines, id, name, count)

      entities = Polyrex.new(schema)
      entities.parse(lines)
      entities.id(id)
      entities.create.entity name: name, count: count

      write entities.to_xml
    end

  end

end

puts testdata.passed?
puts testdata.score
puts testdata.summary.inspect
#puts testdata.success.inspect


