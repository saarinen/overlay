$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "overlay/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "overlay"
  s.version     = Overlay::VERSION
  s.authors     = ["Steve Saarinen"]
  s.email       = ["saarinen@gmail.com"]
  s.homepage    = "http://stevesaarinen.com"
  s.summary     = "Overlay external repository on existing Rails application"
  s.description = "Overlay one or more external repositories on a running Rails application"

  s.files       = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files  = Dir["spec/**/*"]

  s.add_dependency "rails"
  s.add_dependency 'github_api', "~>0.10"
  s.add_dependency 'sucker_punch', '>=1.0.0.beta2'

  s.add_development_dependency 'rspec-rails'
end
