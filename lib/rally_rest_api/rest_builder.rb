require 'net/https'
require 'uri'
require 'rexml/document'
require 'rubygems'	
require 'builder'

# Intended to extend the Net::HTTP response object
# and adds support for decoding gzip and deflate encoded pages
#
# Author: Jason Stirk <http://griffin.oobleyboo.com>
# Home: http://griffin.oobleyboo.com/projects/http_encoding_helper
# Created: 5 September 2007
# Last Updated: 23 November 2007
#
# Usage:
#
# require 'net/http'
# require 'http_encoding_helper'
# headers={'Accept-Encoding' => 'gzip, deflate' }
# http = Net::HTTP.new('griffin.oobleyboo.com', 80)
# http.start do |h|
#   request = Net::HTTP::Get.new('/', headers)
#   response = http.request(request)
#   content=response.plain_body     # Method from our library
#   puts "Transferred: #{response.body.length} bytes"
#   puts "Compression: #{response['content-encoding']}"
#   puts "Extracted: #{response.plain_body.length} bytes"
# end
#

require 'zlib'
require 'stringio'

class Net::HTTPResponse
  # Return the uncompressed content
  def plain_body
    encoding=self['content-encoding']
    content=nil
    if encoding then
      case encoding
        when 'gzip'
          i=Zlib::GzipReader.new(StringIO.new(self.body))
          content=i.read
        when 'deflate'
          i=Zlib::Inflate.new
          content=i.inflate(self.body)
        else
          raise "Unknown encoding - #{encoding}"
      end
    else
      content=self.body
    end
    return content
  end

end


class RestBuilder # :nodoc:

  attr_reader :base_url, :username, :password, :http_headers
  attr_accessor :logger, :use_cookies

  def initialize(base_url, username, password, version = "current", http_headers = CustomHttpHeader.new)
    @base_url, @username, @password, @version, @http_headers = base_url, username, password, version, http_headers
    @cookie_jar = {}
  end

  def marshal_dump
    [@username, @password, @base_url, @version]
  end

  def marshal_load(stuff)
    @username, @password, @base_url, @version = *stuff
  end

  # create_rest - convert slm builder style:
  #    slm.create(:feature, :name => "feature name")
  #
  # Into xml builder style:
  #    b.feature {
  #       b.name("feature name")
  #    }
  # then call create on the REST api
  def create_rest(artifact_type, args, username, password)
    type = camel_case_word(artifact_type)
    debug "RestBuilder#create_rest artifact_type = #{type}"
    b = create_builder
    xml = b.__send__(type, &builder_block(args))
    sleep(3)

    result = post_xml("#{self.base_url}/webservice/#{@version}/#{type}/create", xml, username, password)
    doc = REXML::Document.new result
    doc.root.elements["Object"].to_s
  end

  # update_rest - convert slm builder style:
  #    feature.update(:name => "feature name")
  #
  # Into xml builder style:
  #    b.feature(:ref => "http://...") {
  #       b.name("feature name")
  #    }
  # then call create on the REST api
  def update_rest(artifact_type, url, args, username, password)
    debug  "RestBuilder#update_rest url = #{url}"
    b = create_builder
    # and pass that to the builder
    xml = b.__send__(artifact_type, :ref => url, &builder_block(args))
    sleep(3)
    post_xml(url, xml, username, password)
  end

  def read_rest(ref_url, username, password)
    debug  "RestBuilder#read_rest ref_url = #{ref_url} username = #{ username } pass = #{ password }"
    url = URI.parse(ref_url)
    req = Net::HTTP::Get.new(url.path + (url.query ? "?" + url.query : ""))
    send_request(url, req, username, password)
  end

  def delete_rest(ref_url, username, password)
    debug  "RestBuilder#delete_rest ref_url = #{ref_url} username = #{ username } pass = #{ password }"
    url = URI.parse(ref_url)
    req = Net::HTTP::Delete.new(url.path)
    send_request(url, req, username, password)
  end

  def post_xml(url, xml, username, password)
    debug  "RestBuilder#post_xml xml = #{xml} as user #{ self.username } pass = #{ self.password }"
    url = URI.parse(url)
    req = Net::HTTP::Post.new(url.path)
    req.body = xml
    send_request(url, req, username, password)
  end

  def add_cookies(req)
    req.add_field('cookie', format_cookie(@cookie_jar))
    req
  end

  def parse_cookies (cookie_str)
    cookies = cookie_str.split(', ')
    cookies.collect! { |cookie| cookie.split(";")[0] }

    cookie_jar = {}
    cookies.each do |cookie|
      c = cookie.split("=")
      cookie_jar[c[0]] = c[1] || ""
    end
    cookie_jar
  end

  def format_cookie (cookie_jar)
    cookie_str = ""
    cookie_jar.each do |cookie_name, cookie_value|
      cookie_str += "; " unless cookie_str.empty?
      cookie_str += "#{cookie_name}=#{cookie_value}"
    end
    cookie_str
  end

  def store_cookies(response)
    @cookie_jar.merge!(parse_cookies(response.response['set-cookie']))
    response
  end

  def send_request(url, req, username, password)
    @http_headers.add_headers(req)
    req.basic_auth username, password
    req.content_type = 'text/xml'
    req.add_field('Accept-Encoding', 'gzip, deflate')
    add_cookies(req) if @use_cookies
    proxy = ENV['http_proxy'] ? URI.parse(ENV['http_proxy']) : OpenStruct.new
    http = Net::HTTP.new(url.host, url.port, proxy.host, proxy.port, proxy.user, proxy.password)
    http.use_ssl = true if url.scheme == "https"
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    #http.ssl_version = "SSLv3"
    http.read_timeout = 300
    debug  "RestBuilder#send_request req = #{req.inspect} -- #{url}"
    response = http.start { |http| http.request(req) }
    #debug  "RestBuilder#send_request result = #{response.body}"
    #check_for_errors(response)
    #response.body
    debug  "RestBuilder#send_request result = #{response.plain_body}"
    headerstr = ""
    response.each_header { |k,v| headerstr << "#{k}--#{v}|" }
    store_cookies(response) if @use_cookies
    debug  "RestBuilder#send_request result headers = #{headerstr} and length is #{response.plain_body.length}"
    check_for_errors(response)
    response.plain_body
  end
  
  def create_builder
    b = Builder::XmlMarkup.new
    b.instruct!
    b
  end

  def check_for_errors(response)
    case response
    when Net::HTTPUnauthorized
      raise Rally::NotAuthenticatedError.new("Invalid Username or Password.")
    else
      #s = response.body
      s = response.plain_body
      document = REXML::Document.new s
      node = REXML::XPath.first document, '//Errors'
      raise node.to_s if node && node.has_elements?
    end
  end

  def camel_case_word(sym)
    sym.to_s.split("_").map { |word| word.capitalize }.join
  end
  
  # Because we are adapting to the xml builder as such:
  #  We say to the RallyRestAPI:
  #    slm.create(:feature, :name => "feature name")
  #
  #  We tell the xml builder:
  #    b.feature {
  #       b.name("feature name")
  #    }
  #
  # in the case where one element is a collection, RallyRest would look like
  #    slm.create(:feature, :name => "name", :dependancies => [sr1, sr2])
  # 
  # This needs to be converted to 
  #
  #    b.feature {
  #       b.name("name")
  #       b.Dependancies {
  #         b.SupplementalRequirement(:ref => "http://....")
  #         b.SupplementalRequirement(:ref => "http://....")
  #       }
  #    }
  # in this case we need to create a block to handle the nested calls (b.Supp...)
  #
  #
  # There are also nested/complex values, for example
  # slm.create(:defect, :web_link => {:id => "123", :description => "foo"} )
  #
  #     b.defect {
  #       b.web_link {
  #         b.id "123"
  #         b.description "foo"
  #       }
  #     }
  # 
  # We need to convert the args hash into a block that can be fed to the builder.
  # This will send the keys of the map as "methods" (b.name) and the values of
  # map as the arguments to the method ("feature name"). 
  # 
  # Additionally we camel-case the elements (as JDOM can't handle elements case free).
  # #convert_arg_for_builder will convert the value portion of the hash to the appropiate
  # string, or block for the xml builder
  def builder_block(args)
    sort_block = lambda { |a,b| a.to_s <=> b.to_s }  # Sort the keys, for testing
    lambda do |builder|
      args.sort(&sort_block).each do |(attr, value)|
	if COLLECTION_TYPES.include? attr
	  # The call to builder with only a type and a block needs to be marked as such
	  # note the '&'
	  builder.__send__(camel_case_word(attr), &convert_arg_for_builder([value].flatten))
	elsif value.instance_of? Hash
	  builder.__send__(camel_case_word(attr), &builder_block(value))
	else
	  builder.__send__(camel_case_word(attr), convert_arg_for_builder(value))
	end
      end
    end
  end


  # Convert the values of the hash passed to the RestApi appropiatly
  # RestObject --> a hash with the ref value
  # nil --> "null" ref values
  # Time --> iso8601 time strings
  # Arrays of RestObjects --> block that has a nested xml value
  def convert_arg_for_builder(value)
    case value
    when RestObject
      { :ref => value.ref }
    when NilClass
      { :ref => "null"}
    when Time
      value.iso8601
    when Array
      lambda do |builder|
 	value.each do |rest_object|
 	  builder.__send__(rest_object.type, convert_arg_for_builder(rest_object))
 	end
      end
    else
      value
    end
  end


  COLLECTION_TYPES = [:tags, :dependents, :dependencies, :defects, :duplicates, :children, 
    :predecessors, :test_cases, :artifacts, :changesets]
  def collection_type?(type)
    COLLECTION_TYPES.include?(type)
  end

  def debug(message)
    @logger.debug message if @logger
  end


end

