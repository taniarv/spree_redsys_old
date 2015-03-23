# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_redsys'
  s.version     = '3.0.0'
  s.summary     = 'Adds Redsys TPV as payment method for Spree'
  s.description = 'Redsys is an Spanish payment gateway. '
  s.required_ruby_version = '>= 1.9.3'

  s.author    = 'Tania'
  s.email     = 'taniarubiov@gmail.com'
  
  #s.files       = `git ls-files`.split("\n")
  #s.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', '~> 3.0.0'
end
