dir = File.dirname(__FILE__)
app_path = File.expand_path("#{dir}/../lib")
$LOAD_PATH.unshift app_path unless $LOAD_PATH.include?(app_path)
require 'test/unit'
require 'rubygems'
require 'rspec'
require 'net/http'
require 'rally_rest_api'

class RallyRestAPI
  def user; end
end

