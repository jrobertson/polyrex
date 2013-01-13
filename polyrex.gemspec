Gem::Specification.new do |s|
  s.name = 'polyrex'
  s.version = '0.8.24'
  s.summary = 'polyrex'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_dependency('polyrex-schema')
  s.add_dependency('line-tree')
  s.add_dependency('polyrex-objects')
  s.add_dependency('polyrex-createobject')
  s.add_dependency('polyrex-object-methods')
  s.add_dependency('recordx-xslt')
end
