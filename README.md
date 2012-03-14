# Introducing the Polyrex gem

    require 'polyrex' 

    polyrex = Polyrex.new 'entities/section[name]/entity[name,count]' 
    polyrex.create.section(name: 'main') do |create|  
      create.entity name: 'entry', count: 1 
    end

    polyrex.create.section(name: 'tags') do |create|
      create.entity name: 'ruby', count: 1 
      create.entity name: 'rexml', count: 1 
      create.entity name: 'array', count: 1 
    end
    puts polyrex.to_xml pretty: true

    (polyrex.public_methods - Object.public_methods).sort
    #=> [:create, :create_entity, :create_section, :delete, :element, :entity, :find_by_entity_count, :find_by_entity_name, :find_by_id, :find_by_section_name, :format_masks, :id, :id_counter, :id_counter=, :parse, :record, :records, :save, :schema, :schema=, :section, :summary, :summary_fields, :summary_fields=, :to_a, :to_xml, :to_xslt, :xpath, :xslt_schema, :xslt_schema=]
