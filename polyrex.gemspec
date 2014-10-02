Gem::Specification.new do |s|
  s.name = 'polyrex'
  s.version = '0.9.12'
  s.summary = 'polyrex'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_runtime_dependency('polyrex-schema', '~> 0.1', '>=0.1.15')
  s.add_runtime_dependency('line-tree', '~> 0.3', '>=0.3.17')
  s.add_runtime_dependency('polyrex-objects', '~> 0.7', '>=0.7.8')
  s.add_runtime_dependency('polyrex-createobject', '~> 0.4', '>=0.4.15')
  s.add_runtime_dependency('polyrex-object-methods', '~> 0.1', '>=0.1.2')
  s.add_runtime_dependency('recordx-xslt', '~> 0.1', '>=0.1.3') 
  s.add_runtime_dependency('dynarex', '~> 1.2', '>=1.2.90')
  s.signing_key = '../privatekeys/polyrex.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/polyrex'
  s.required_ruby_version = '>= 2.1.0'
end
