require File.dirname(__FILE__) + '/../test_helper'

describe "a RestBuilder " do

  def xml
    b = Builder::XmlMarkup.new
    b.instruct!
    yield b
  end

  before(:each) do
    @username = "username"
    @password = "password"
    @builder = RestBuilder.new(nil, @username, @password)
  end
  
  it "should produce correct xml for flat xml" do
    expected_xml = xml do |b|
      b.defect(:ref => "url") {
	b.Name "foo"
      }
    end
    @builder.should_receive(:post_xml).with(anything(), expected_xml, @username, @password)
    @builder.update_rest(:defect, "url", {:name => "foo"}, @username, @password)
  end
  
  it "should produce correct xml for nested values" do
    expected_xml = xml do |b|
      b.defect(:ref => "url") {
	b.Name "foo"
	b.WebLink {
	  b.DisplayString "desc"
	  b.LinkID "12345"
	}
      }
    end

    @builder.should_receive(:post_xml).with(anything(), expected_xml, @username, @password)
    @builder.update_rest(:defect, "url", 
			 {
			   :name => "foo", 
			   :web_link => {
			     :display_string => "desc",
			     :link_i_d => "12345"
			   }
			 }, @username, @password)
  end

  it "should raise an error if the response contains an Error element" do
    body = "<xml><Errors><Error/></Errors></xml>"
    response = mock("response")
    response.should_receive(:plain_body).and_return(body)
    lambda { @builder.check_for_errors(response) }.should raise_error(StandardError)
  end

  it "should raise a NotAuthenticatedError when a 401 response is returned" do
    response = Net::HTTPUnauthorized.new("1.1", "401", "message")
    lambda { @builder.check_for_errors(response) }.should raise_error(Rally::NotAuthenticatedError, /Invalid Username or Password/)
  end

end
