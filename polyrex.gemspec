Gem::Specification.new do |s|
  s.name = 'polyrex'
  s.version = '0.6.0'
  s.summary = 'polyrex'
  s.files = Dir['lib/**/*.rb']
  s.add_dependency('polyrex-schema')
  s.add_dependency('line-tree')
  s.add_dependency('polyrex-objects')
  s.add_dependency('polyrex-createobject')
end
