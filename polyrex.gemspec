Gem::Specification.new do |s|
  s.name = 'polyrex'
  s.version = '0.3.5'
  s.summary = 'polyrex'
  s.files = Dir['lib/**/*.rb']
  s.add_dependency('backtrack-xpath')
  s.add_dependency('polyrex-schema')
  s.add_dependency('line-tree')
end
