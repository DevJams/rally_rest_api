# Look in the tasks/setup.rb file for the various options that can be
# configured in this Rakefile. The .rake files in the tasks directory
# are where the options are used.


load 'tasks/setup.rb'

ensure_in_path 'lib'
require 'rally_rest_api'

task :default => 'spec:run'

PROJ.name = 'rally_rest_api'
PROJ.authors = 'Bob Cotton'
PROJ.email = 'bob.cotton@rallydev.com'
PROJ.url = 'http://rally-rest-api.rubyforge.org/rally_rest_api'
PROJ.rubyforge.name = 'rally-rest-api'
PROJ.summary = "A Ruby interface to the Rally REST API"
PROJ.version = RallyRestVersion::LIBRARY_VERSION::STRING

PROJ.exclude = ['.git/*', 'pkg/*']

PROJ.rdoc.dir = 'doc/output/rally_rest_api'

PROJ.spec.opts << '--color'

# EOF
