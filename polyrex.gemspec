Gem::Specification.new do |s|
  s.name = 'polyrex'
  s.version = '1.1.9'
  s.summary = 'A flavour of XML for storing and retrieveing records in a Polyrex hierarchy'
  s.authors = ['James Robertson']
  s.files = Dir['lib/polyrex.rb']
  s.add_runtime_dependency('polyrex-schema', '~> 0.4', '>=0.4.2')
  s.add_runtime_dependency('polyrex-objects', '~> 0.9', '>=0.9.2')
  s.add_runtime_dependency('polyrex-createobject', '~> 0.6', '>=0.6.0')
  s.add_runtime_dependency('polyrex-object-methods', '~> 0.2', '>=0.2.2')
  s.add_runtime_dependency('recordx-xslt', '~> 0.1', '>=0.1.4') 
  s.add_runtime_dependency('dynarex', '~> 1.7', '>=1.7.14')
  s.signing_key = '../privatekeys/polyrex.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/polyrex'
  s.required_ruby_version = '>= 2.1.0'
end
