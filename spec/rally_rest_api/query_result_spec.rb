require File.dirname(__FILE__) + '/../test_helper'

describe "A QueryResult" do

  before(:each) do
    @api = RallyRestAPI.new(:parse_collections_as_hash => true)
  end

  def make_result(total = 20, page_size = 20, start_index = 1)
    result_count = total > page_size ? page_size : total

    b = Builder::XmlMarkup.new(:indent => 2)
    xml = b.QueryResult {
      b.TotalResultCount total
      b.PageSize page_size
      b.StartIndex start_index

      if (result_count > 0)
	b.Results {
	  result_count.times { |i| b.RefElement(:ref => "http", :refObjectName => "name#{i}") }
	}
      else
	b.Results
      end
    }

    QueryResult.new(nil, @api, xml)
  end

  it "should have the total result count" do
    make_result(20, 20, 1).total_result_count.should equal(20)
  end

  it "should have the page size" do
    make_result(20, 20, 1).page_size.should equal(20)
  end

  it "should have the start_index" do
    make_result(20, 20, 1).start_index.should equal(1)
  end

  it "should have no more pages when no results are returned" do
    make_result(0, 20, 0).more_pages?.should equal(false)
  end

  it "should have not more pages when the total result count is less then the page size" do
    make_result(1, 20, 1).more_pages?.should equal(false)
    make_result(19, 20, 1).more_pages?.should equal(false)
    make_result(20, 20, 1).more_pages?.should equal(false)
  end

  it "should have more pages when total result count is more then the page size" do
    make_result(21, 20, 1).more_pages?.should equal(true)
    make_result(39, 20, 1).more_pages?.should equal(true)
  end

  it "an empty query should not iteratate on each" do
    start = 0
    make_result(0, 20, 0).each { start += 1 }
    start.should equal(0)
  end

  it "a page of results should match the page size" do
    make_result(20, 20, 1).results.length.should equal(20)
  end

  it "results should be in the same order as returned" do
    result = make_result(20, 20, 1)
    result.results.length.should equal(20)
    result.results[0].name.should == "name0"
    result.results[19].name.should == "name19"
  end

  it "should return RestObjects for results" do
    make_result.each { |o| o.should be_instance_of(RestObject) }
  end
end


describe "A QueryResult with full objects" do

  before(:each) do
    @api = RallyRestAPI.new(:parse_collections_as_hash => true)
  end

  def make_result(total = 20, page_size = 20, start_index = 1)
    result_count = total > page_size ? page_size : total

    b = Builder::XmlMarkup.new(:indent => 2)
    xml = b.QueryResult {
      b.TotalResultCount total
      b.PageSize page_size
      b.StartIndex start_index

      if (result_count > 0)
	b.Results {
	  result_count.times do |i| 
	    b.RefElement(:ref => "http", :refObjectName => "name#{i}") {
	      b.Name("This is the name for #{i}")
	    }
	  end
	}
      else
	b.Results
      end
    }

    QueryResult.new(nil, @api, xml)
  end

  def query_result_xml(&block)
    QueryResult.new(nil, @api, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{xml &block}")
  end

  def xml
    yield Builder::XmlMarkup.new(:indent => 2)
  end

  it "should return RestObjects for results" do
    make_result.each { |o| o.should be_instance_of(RestObject) }
  end

  it "full object collections should lazy load only once" do
    rest_builder = mock("RestBuilder")
    rest_builder.
      should_receive(:read_rest).
      twice.
      with(any_args(), nil, nil).
      and_return( xml do |b| 
		   b.iteration { 
		     b.Name("name1")
		     b.StartDate("12/12/01")
		   } 
		 end )

    @api = RallyRestAPI.new(:builder => rest_builder)

    object = query_result_xml do |b| 
      b.QueryResult {
	b.TotalResultCount 2
	b.PageSize 20
	b.StartIndex 1

	b.Results {
	  b.Card(:ref => "http", :refObjectName => "Card1") {
	    b.Name("Card1")
	    b.Description("Description1")
	    b.Iteration(:ref => "http", :refObjectName => "name1")
	  }
	  b.Card(:ref => "http", :refObjectName => "Card2") {
	    b.Name("Card2")
	    b.Description("Description2")
	    b.Iteration(:ref => "http", :refObjectName => "name1")
	  }
	}
      }
    end

    object.total_result_count.should equal(2)
    object.results.should be_instance_of(Array)
    object.each_with_index do |c, i| 
      c.name.should == "Card#{i + 1}"
      c.description.should == "Description#{i + 1}"
      c.iteration.start_date.should == "12/12/01"
      c.iteration.start_date.should == "12/12/01"
    end

  end

end
