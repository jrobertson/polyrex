Gem::Specification.new do |s|
  s.name = 'polyrex'
  s.version = '1.0.13'
  s.summary = 'A flavour of XML for storing and retrieveing records in a Polyrex hierarchy'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_runtime_dependency('polyrex-schema', '~> 0.4', '>=0.4.0')
  s.add_runtime_dependency('polyrex-objects', '~> 0.8', '>=0.8.5')
  s.add_runtime_dependency('polyrex-createobject', '~> 0.5', '>=0.5.7')
  s.add_runtime_dependency('polyrex-object-methods', '~> 0.2', '>=0.2.2')
  s.add_runtime_dependency('recordx-xslt', '~> 0.1', '>=0.1.4') 
  s.add_runtime_dependency('dynarex', '~> 1.4', '>=1.4.1')
  s.signing_key = '../privatekeys/polyrex.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/polyrex'
  s.required_ruby_version = '>= 2.1.0'
end
