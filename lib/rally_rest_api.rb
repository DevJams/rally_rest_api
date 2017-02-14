Dir[File.join(File.dirname(__FILE__), 'rally_rest_api/**/*.rb')].sort.each { |lib| require lib }
begin
  require 'rubygems'
  require 'ruport'
  require 'rally_rest_api/ruport'
rescue LoadError
end
