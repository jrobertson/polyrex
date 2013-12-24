Gem::Specification.new do |s|
  s.name = 'polyrex'
  s.version = '0.8.39'
  s.summary = 'polyrex'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_dependency('polyrex-schema')
  s.add_dependency('line-tree')
  s.add_dependency('polyrex-objects')
  s.add_dependency('polyrex-createobject')
  s.add_dependency('polyrex-object-methods')
  s.add_dependency('recordx-xslt') 
  s.add_dependency('dynarex')
  s.signing_key = '../privatekeys/polyrex.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/polyrex'
end
