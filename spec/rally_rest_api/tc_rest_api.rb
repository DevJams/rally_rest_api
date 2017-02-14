require File.dirname(__FILE__) + '/../test_helper'
class RestApiTestCase < Test::Unit::TestCase

  # We need to override post_xml from RestBuilder, So redefine it here
  # We want this post_xml to set the xml that was received onto the testcase
  # So create an xml= on the test, and pass the test into the RallyRestAPI
  class LocalBuilder < RestBuilder
    def initialize(test)
      @test = test
    end
    def post_xml(url, xml, username, password)
      @test.xml = xml
      "<CreateResult><Object/></CreateResult>"
    end
  end
  
  def xml=(xml)
    @xml = xml
  end
  
  def setup
    super
    @api = RallyRestAPI.new(:builder => LocalBuilder.new(self))
  end

  def preamble
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  end

  # This covers:
  #  - Camel casing basic types and names
  #  - String values
  def test_basic_create
    xml = "#{preamble}<Feature><Name>name</Name></Feature>"
    @api.create(:feature, :name => "name")
    assert_equal(xml, @xml)
  end

  def test_basic_create
    xml = "#{preamble}<Feature><Name>name</Name></Feature>"
    object = @api.create(:feature, :name => "name")
    assert_equal(RallyRestAPI, object.rally_rest.class)
  end

  # test that types and keys are camel cased (at least with one underscore)
  def test_camel_case
    xml = "#{preamble}<UseCase><NameName>name</NameName></UseCase>"
    @api.create(:use_case, :name_name => "name")
    assert_equal(xml, @xml)
  end

  def test_nil_value
    xml = %Q(#{preamble}<UseCase><Name ref="null"/></UseCase>)
    @api.create(:use_case, :name => nil)
    assert_equal(xml, @xml)
  end

  def test_time_value
    time = Time.now
    xml = "#{preamble}<UseCase><Time>#{time.iso8601}</Time></UseCase>"
    @api.create(:use_case, :time => time)
    assert_equal(xml, @xml)
  end

  # check passing one RestObject as the value
  def test_rest_object_value
    rest_object_xml = %Q(<Feature ref="url"><Name>name</Name></Feature>)
    rest_object = RestObject.new(@api, rest_object_xml)

    xml = %Q(#{preamble}<Feature><UseCase ref="url"/></Feature>)
    @api.create(:feature, :use_case => rest_object)
    assert_equal(xml, @xml)
  end

  # Check for passing a single RestObject as the value to a collection node
  def test_rest_object_array_value
    rest_object_xml = %Q(<UseCase ref="url"><Name>name</Name></UseCase>)
    uc1 = RestObject.new(@api, rest_object_xml)

    xml = %Q(#{preamble}<Feature><Dependents><UseCase ref="url"/></Dependents></Feature>)
    @api.create(:feature, :dependents => uc1)
    assert_equal(xml, @xml)
  end

  # Check for passing an array of RestObjects as the value
  def test_rest_object_array_value_multiple_values
    rest_object_xml = %Q(<UseCase ref="url"><Name>name</Name></UseCase>)
    uc1 = RestObject.new(@api, rest_object_xml)
    uc2 = RestObject.new(@api, rest_object_xml)

    xml = %Q(#{preamble}<Feature><Dependents><UseCase ref="url"/><UseCase ref="url"/></Dependents></Feature>)
    @api.create(:feature, :dependents => [uc1, uc2])
    assert_equal(xml, @xml)
  end
  
  def test_default_base_url_should_be_rally_proudction
    assert_equal("https://rally1.rallydev.com/slm", @api.base_url)
  end

end
