require File.dirname(__FILE__) + '/../test_helper'

require 'ostruct'
require 'logger'


describe "An attribute definition for a custom dropdown" do

  before(:each) do
    @b = Builder::XmlMarkup.new(:indent => 2)
    @b.instruct!
    
    xml = @b.AttributeDefinition(:ref => "http://bla/bla/bla", 
				 :refObjectName => "Custom Dropdown") {
      @b.Name("Custom Dropdown")
      @b.AttributeType("STRING")
      @b.ElementName("CustomDropdown")
      @b.Constrained("true")
      @b.Custom("true")

      @b.AllowedValues {
	@b.AllowedAttributeValue(:ref => "null") {
	  @b.StringValue
	}
	@b.AllowedAttributeValue(:ref => "null") {
	  @b.StringValue("Actor")
	}
      }
    }
    fake_rally_rest = OpenStruct.new(:username => "", :password => "", :logger => nil)
    @attrdef = AttributeDefinition.new(fake_rally_rest, RestObject.new(fake_rally_rest, xml).elements)    
  end

  it "should have 'Custom Dropdown' as the name" do
    @attrdef.name.should == "Custom Dropdown"
  end

  it "should return an arry of allowed values" do
    @attrdef.allowed_values.should be_instance_of(Array)
  end
 
  it "should have 2 allowd values" do
    @attrdef.allowed_values.length.should == 2
  end

  it "should not return an array of hashes" do
    @attrdef.allowed_values.each { |value| value.should_not be_instance_of(Hash) }
  end
  
  it "allowed_values should match" do
    @attrdef.allowed_values.should == [nil, "Actor"]
  end

  it "should have 'AttributeDefinition' as the type" do
    @attrdef.type.should == "AttributeDefinition"
  end

end
