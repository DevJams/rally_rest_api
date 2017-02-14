lib = File.expand_path('../lib/', __FILE__)  
$:.unshift lib unless $:.include?(lib)

require 'rally_rest_api/version'

Gem::Specification.new do |s|  
  s.name        = "rally_rest_api"
  s.version     = RallyRestVersion::LIBRARY_VERSION::STRING
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["bob.cotton@rallydev.com"]
  s.email       = ["bob.cotton@rallydev.com"]
  s.summary     = "A Ruby interface to the Rally REST API" 

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "bundler"

  s.files        = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.md ROADMAP.md CHANGELOG.md)
  s.executables  = ['bundle']
  s.require_path = 'lib'
end  
