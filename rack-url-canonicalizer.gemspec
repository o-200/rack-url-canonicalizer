# frozen_string_literal: true

require_relative 'lib/rack/url_canonicalizer/version'

Gem::Specification.new do |spec|
  spec.name          = 'rack-url-canonicalizer'
  spec.version       = Rack::UrlCanonicalizer::VERSION
  spec.authors       = ['Alex Abramov']
  spec.email         = ['omgout.200@gmail.com']

  spec.summary       = 'Rack middleware for URL normalization and SEO canonicalization'
  spec.description   = 'Removes www, collapses slashes, strips trailing slashes, and validates locale params to prevent duplicate content SEO penalties.'
  spec.homepage      = 'https://github.com/o-200/rack-url-canonicalizer'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.files         = Dir['LICENSE.txt', 'README.md', 'lib/**/*']
  spec.require_paths = ['lib']

  spec.add_dependency 'rack', '>= 2.0'

  spec.add_development_dependency 'bundler', '>= 2.0'
  spec.add_development_dependency 'parallel', '< 2.1.0'
  spec.add_development_dependency 'rack-test', '>= 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
