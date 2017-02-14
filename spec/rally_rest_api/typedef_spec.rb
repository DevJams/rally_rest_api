require File.dirname(__FILE__) + '/../test_helper'
require 'ostruct'


describe "A Test Case type definition with 2 collection attribues, 1 object attributes, and 1 string attribute" do
  
  before(:each) do
    @b = Builder::XmlMarkup.new(:indent => 2)
    @b.instruct!
    
    xml = @b.TypeDefinition(:ref => "https://rally1.rallydev.com:443/slm/webservice/1.0/typedefinition/31552422",
		      :refObjectName => "Test Case",
		      :type => "TypeDefinition") {
      @b.ElementName("TestCase")
      @b.Attributes {
	 {"Notes"             => {:type => "TEXT", :element_name => "Notes", :constrained => "false", :custom => "false"},
      "Test Case Result" => {:type => "COLLECTION", :element_name => "TestCaseResult", :constrained => "false", :custom => "false"},
	  "Foo Bar"          => {:type => "COLLECTION", :element_name => "FooBar", :constrained => "false", :custom => "false"},
	  "Requirement"      => {:type => "OBJECT", :element_name => "Requirement", :constrained => "false", :custom => "false"},
      "Constrained"      => {:type => "STRING", :element_name => "Constrained", :constrained => "true", :custom => "false"},
	  "Custom"           => {:type => "STRING", :element_name => "Custom", :constrained => "false", :custom => "true"},
	  "ConstainedCustom" => {:type => "STRING", :element_name => "ConstrainedCustom", :constrained => "true", :custom => "true"}
	}.each do |name, type|
	  @b.AttributeDefinition(:ref => "http://bla/bla/bla", 
				 :refObjectName => name) {
	      @b.AttributeType(type[:type])
	      @b.ElementName(type[:element_name])
	      @b.Constrained(type[:constrained])
	      @b.Custom(type[:custom])
	  }
	end
      }
    }
    @typedef = TypeDefinition.new(OpenStruct.new(:username => "", :password => "", :logger => nil), xml)
  end

  it "all attribute keys are symbols" do
    @typedef.attributes.keys.each { |a| a.should be_instance_of(Symbol) }
  end

  it "there should be 2 collection attributes" do
    @typedef.collection_attributes.size.should == 2
  end
  
  it "the :test_case_result attribute should exist" do
    @typedef.collection_attributes[:test_case_result].should_not be_nil
  end

  it "All the collection attributes keys should be symbols" do
    @typedef.collection_attributes.keys.each { |a| a.should be_instance_of(Symbol) }
  end
  
  it "there should be 1 object attribute" do
    @typedef.object_attributes.size.should == 1
  end

  it "the :requirement attribute should exist" do
    @typedef.object_attributes[:requirement].should_not be_nil
  end

  it "should have 2 constrained attributes" do
    @typedef.constrained_attributes.size.should == 2
  end

  it "should have 2 cusom attributes" do
    @typedef.custom_attributes.size.should == 2
  end

  it "should have 1 custom_constrained_attributes" do
    @typedef.custom_constrained_attributes.size.should equal(1)
    @typedef.custom_dropdown_attributes.size.should equal(1)
  end

  it "#attributes should return instances of AttributeDefinitions" do
    @typedef.attributes.values.each { |attrdef| attrdef.should be_instance_of(AttributeDefinition) }
  end

  it "should have a nil parent" do
    @typedef.parent.should be_nil
  end

  it "should not throw exception Marshalling" do
    lambda { Marshal.dump(@typedef) }.should_not raise_error Exception
  end
  
end
