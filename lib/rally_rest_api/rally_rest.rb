require 'net/http'
require 'uri'
require 'rexml/document'
require 'ostruct'

module Rally
  class NotAuthenticatedError < StandardError; end
end

#
# RallyRestAPI - A Ruby-ized interface to Rally's REST webservice API
#
class RallyRestAPI
 
  attr_reader :username, :password, :base_url, :logger, :builder
  attr_accessor :parse_collections_as_hash

  ALLOWED_TYPES = %w[subscription workspace project iteration release defect defect_suite test_case
                     feature supplemental_requirement use_case story actor card
                     program task hierarchical_requirement test_case_result test_case_step]
  
  # new - Create an instance of RallyRestAPI. Each instance corresponds to one named user.
  #
  # options (as a Hash):
  # * username     - The Rally username
  # * password     - The password for the named user
  # * base_url     - The base url of the system. Defaults to https://rally1.rallydev.com/slm
  # * version      - The RallyWebservices Version. Defaults to 'current', which will always be the most
  #               recent version of the api. Pass the value as a String, "1.0", "1.01" for example.
  # * logger       - a Logger to log to.
  # * http_headers - an instace of CustomHttpHeader that will send application information with the request
  #
  def initialize(options = {})
    parse_options(options)
    user
  end

  def parse_options(options)
    @username = options[:username]
    @password = options[:password]
    @base_url = options[:base_url] || "https://rally1.rallydev.com/slm"
    @version = options[:version] || "1.36"
    @logger = options[:logger]
    @http_headers = options[:http_headers] || CustomHttpHeader.new
    @parse_collections_as_hash = options[:parse_collections_as_hash] || false

    if options[:builder]
      builder = options[:builder]
    else
      builder = RestBuilder.new(@base_url, @username, @password, @version, @http_headers)
    end
    builder.logger = @logger if @logger
    builder.use_cookies = true if options[:use_cookies]
    @builder = builder
  end

  def marshal_dump
    [@username, @password, @base_url, @version, @builder, @parse_collections_as_hash]
  end

  def marshal_load(stuff)
    @username, @password, @base_url, @version, @builder, @parse_collections_as_hash = *stuff
  end


  # return an instance of User, for the currently logged in user. 
  def user
    RestObject.new(self, builder.read_rest("#{@base_url}/webservice/#{@version}/user", @username, @password))
  end
  alias :start :user # :nodoc:

  # Create an object.
  #  type   - The type to create, as a symbol (e.g. :test_case)
  #  values - The attributes of the new object.
  #
  # The created instance will be passed to the block
  #
  # returns the created object as a RestObject.
  def create(type, values) # :yields: new_object
#    raise "'#{type}' is not a supported type. Supported types are: #{ALLOWED_TYPES.inspect}" unless ALLOWED_TYPES.include?(type.to_s)
    xml = builder.create_rest(type, values, @username, @password)
    object = RestObject.new(self, xml)
    yield object if block_given?
    object
  end

  # Query Rally for a collection of objects
  # Example :
  #   rally.find(:artifact, :pagesize => 20, :start => 20) { equal :name, "name" }
  # See RestQuery for more info.
  def find(type, args = {}, &query_block)
    # pass the args to RestQuery, make it generate the string and handle generating the query for the 
    # next page etc.
    query = RestQuery.new(type, args, &query_block)
    query(query)
  end

  # find all object of a given type. Base types work also (e.g. :artifact)
  def find_all(type, args = {})
    find(type, args) { gt :object_i_d, "0" }
  end

  # update - update an object
  def update(rest_object, attributes)
    rest_object.update(attributes)
  end

  # delete an object
  def delete(rest_object)
    rest_object.delete
  end
  
  def query(query) # :nodoc:
    query_url = "#{@base_url}/webservice/#{@version}/#{query.type.to_s.to_camel}?" << query.to_q
    xml = builder.read_rest(query_url, @username, @password)
    QueryResult.new(query, self, xml)
  end

  # Should rest_objects collection parse into hashes
  def parse_collections_as_hash?
    @parse_collections_as_hash
  end

  protected
  def debug(message) 
    @logger.debug(message) if @logger
  end

end



