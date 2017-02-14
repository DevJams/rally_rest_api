require File.dirname(__FILE__) + '/../test_helper'

describe "A CustomHttpHeader" do

  before(:each) do
    @custom_http_header = CustomHttpHeader.new
    @sample_values = {
      :library  => "RallyRestAPI version #{RallyRestVersion::LIBRARY_VERSION::STRING}",
      :platform => "Ruby #{RUBY_VERSION}",
      :os       => RUBY_PLATFORM,
      :name     => 'Guacamole',
      :vendor   => "The Big Enchilda's Burrito Company",
      :version  => '0.3.2'
    }
  end
  
  it "should set library, platform, and os automatically" do
    @custom_http_header.library.should == @sample_values[:library]
    @custom_http_header.platform.should == @sample_values[:platform]
    @custom_http_header.os.should == @sample_values[:os]
  end

  it 'should allow name, version, and vendor to be set' do
    [:name, :vendor, :version].each do |field, value|
      @custom_http_header.send("#{field}=".to_sym, value)
      @custom_http_header.send(field).should == value
    end
  end

  it 'should set the HTTP headers appropriately' do
    req = mock("HTTP Request")
    [:name, :vendor, :version].each do |field|
      @custom_http_header.send("#{field}=", @sample_values[field])
    end

    @sample_values.each do |header, value|
      hdr = "#{CustomHttpHeader::HTTP_HEADER_PREFIX}#{header.to_s.capitalize}"
      req.should_receive(:add_field).with(hdr, value)
    end
    @custom_http_header.add_headers(req)
  end

  it "should default the 'name' to be RubyRestAPI if none given" do
    @custom_http_header.name.should == "RubyRestAPI"
  end

end
