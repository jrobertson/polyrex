Gem::Specification.new do |s|
  s.name = 'polyrex'
  s.version = '1.3.0'
  s.summary = 'A flavour of XML for storing and retrieveing ' + 
      'records in a Polyrex hierarchy'
  s.authors = ['James Robertson']
  s.files = Dir['lib/polyrex.rb']
  s.add_runtime_dependency('polyrex-objects', '~> 1.0', '>=1.0.1')
  s.add_runtime_dependency('polyrex-object-methods', '~> 0.2', '>=0.2.2')
  s.add_runtime_dependency('recordx-xslt', '~> 0.2', '>=0.2.2') 
  s.add_runtime_dependency('dynarex', '~> 1.8', '>=1.8.19')
  s.signing_key = '../privatekeys/polyrex.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/polyrex'
  s.required_ruby_version = '>= 2.1.0'
end
