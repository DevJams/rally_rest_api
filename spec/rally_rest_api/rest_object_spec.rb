require File.dirname(__FILE__) + '/../test_helper'

describe RestObject do

  before(:each) do
    @api = RallyRestAPI.new
  end

  def rest_object(xml)
    RestObject.new(@api, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{xml}")
  end

  def rest_object_xml(&block)
    RestObject.new(@api, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{xml &block}")
  end

  def b 
    @b ||= Builder::XmlMarkup.new(:indent => 2)
  end

  def xml
    yield Builder::XmlMarkup.new(:indent => 2)
  end

  it "should return the type of the resource from a ref" do
    o = rest_object_xml do |b|
      b.Object(:refObjectName => "name", :ref => "ref", :type => "Defect")
    end
    o.type.should == "Defect"
  end

  it "should return the type of the resource from full object" do
    o = rest_object_xml do |b|
      b.Defect(:refObjectName => "name", :ref => "ref") {
	b.Name("name")
      }
    end
    o.type.should == "Defect"
  end

  it "should return the ref of the resource " do
    o = rest_object_xml do |b|
      b.Defect(:refObjectName => "name", :ref => "ref") {
	b.Name("name")
      }
    end
    o.ref.should == "ref"
  end

  it "should return the oid" do
    o = rest_object_xml do |b|
      b.Defect(:refObjectName => "name", :ref => "ref") {
	b.Name("name")
	b.ObjectID("12345")
      }
    end
    o.oid.should == "12345"
  end

  it "should underscore element names" do
    o = rest_object(%Q(<Object ref="bla">
                              <TextNode>text</TextNode>
                            </Object>))
    o.text_node.should_not equal nil
    o.TextNode.should equal(nil)
    o.Text_Node.should equal(nil)
    o.textnode.should equal(nil)
  end

  it "should underscore elements ending in 'ID' correctly" do
    o = rest_object(%Q(<Object ref="bla">
                              <SalesforceCaseID>12345</SalesforceCaseID>
                            </Object>))
    o.salesforce_case_i_d.should == "12345"
  end

  it "should return text nodes" do
    xml = %Q(<Object ref="bla">
               <TextNode>text</TextNode>
             </Object>)
    rest_object(xml).text_node.should == "text"
  end

  it "should return nested text nodes" do
    xml = %Q(<Object ref="bla">
               <Nested>
                 <TextNode>text</TextNode>
               </Nested>
             </Object>)
    rest_object(xml).nested.text_node.should == "text"
  end

  it "should lazy read ref elements" do
    rest_builder = mock("RestBuilder")
    rest_builder.
      should_receive(:read_rest).
      with(any_args()).
      and_return( xml do |b| 
		   b.TestCase { 
		     b.Name("name1")
		     b.Description("Description")
		   } 
		 end )

    @api = RallyRestAPI.new(:builder => rest_builder)

    object = rest_object_xml do |b| 
      b.TestCase(:ref => "http", :name => "name1")
    end
    object.description.should == "Description"
  end
  
  it "should lazy read nested ref elements" do
    rest_builder = mock("RestBuilder")
    rest_builder.
      should_receive(:read_rest).
      with(any_args()).
      and_return( xml do |b| 
		   b.TestCase { 
		     b.Name("name1")
		     b.Description("Description")
		   } 
		 end )

    @api = RallyRestAPI.new(:builder => rest_builder)

    object = rest_object_xml do |b| 
      b.Defect(:ref => "http") {
	b.TestCase(:ref => "http", :refObjectName => "name1")
      }
    end
    object.test_case.should be_instance_of(RestObject)
    object.test_case.type.should == "TestCase"
    object.test_case.description.should == "Description"
  end

  it "should lazy read only once nested ref elements" do
    rest_builder = mock("RestBuilder")
    rest_builder.
      should_receive(:read_rest).
      once.
      with(any_args()).
      and_return( xml do |b| 
		   b.TestCase { 
		     b.Name("name1")
		     b.Description("Description")
		   } 
		 end )

    @api = RallyRestAPI.new(:builder => rest_builder)

    object = rest_object_xml do |b| 
      b.Defect(:ref => "http") {
	b.TestCase(:ref => "http", :refObjectName => "name1")
      }
    end
    object.test_case.description.should == "Description"
    object.test_case.description.should == "Description"
  end

  it "should lazy load only once full object collections" do
    rest_builder = mock("RestBuilder")
    rest_builder.
      should_receive(:read_rest).
      once.
      with(any_args()).
      and_return( xml do |b| 
		   b.iteration { 
		     b.Name("name1")
		     b.StartDate("12/12/01")
		   } 
		 end )

    @api = RallyRestAPI.new(:builder => rest_builder)

    object = rest_object_xml do |b| 
      b.QueryResult {
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

    object.results.length.should equal(2)
    object.results.should be_instance_of(Array)
    object.results.first.description.should == "Description1"
    object.results.first.iteration.start_date.should == "12/12/01"
    object.results.first.iteration.start_date.should == "12/12/01"
  end

  it "should dump and load" do

    @api = RallyRestAPI.new

    object = rest_object_xml do |b| 
      b.QueryResult {
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

    new_object = Marshal.load(Marshal.dump(object))

    new_object.results.length.should equal(2)
    new_object.results.should be_instance_of(Array)
    new_object.results.first.description.should == "Description1"
  end


  it "should parse collections as arrays " do
    @api = RallyRestAPI.new(:parse_collections_as_hash => false)

    object = rest_object_xml do |b|
      b.Story(:refObjectName => "story", :ref => "http") {
	b.Tasks {
	  b.Task(:refObjectName => "task1", :ref => "ref")
	  b.Task(:refObjectName => "task2", :ref => "ref")
	  b.Task(:refObjectName => "task3", :ref => "ref")
	}
      }
    end
    object.tasks.should be_instance_of(Array)
    object.tasks.length.should equal(3)
  end

  it "should parse collections as hashes " do
    @api = RallyRestAPI.new(:parse_collections_as_hash => true)

    object = rest_object_xml do |b|
      b.Story(:refObjectName => "story", :ref => "http") {
	b.Tasks {
	  b.Task(:refObjectName => "task1", :ref => "ref")
	  b.Task(:refObjectName => "task2", :ref => "ref")
	  b.Task(:refObjectName => "task3", :ref => "ref")
	}
      }
    end
    object.tasks.should be_instance_of(Hash)
    object.tasks.length.should equal(3)
  end

  it "should dup names into arrays, when collections are parsed as hashes" do
    @api = RallyRestAPI.new(:parse_collections_as_hash => true)

    object = rest_object_xml do |b|
      b.Story(:refObjectName => "story", :ref => "http") {
	b.Tasks {
	  b.Task(:refObjectName => "task1", :ref => "ref")
	  b.Task(:refObjectName => "task2", :ref => "ref")
	  b.Task(:refObjectName => "task2", :ref => "ref")
	}
      }
    end
    object.tasks.should be_instance_of(Hash)
    object.tasks.length.should equal(2)
    object.tasks["task2"].should be_instance_of(Array)
    object.tasks["task2"].length.should equal(2)
  end

  it "should parse unnamed elements into arrays when collections are parsed as hashes" do
    @api = RallyRestAPI.new(:parse_collections_as_hash => true)

    object = rest_object_xml do |b|
      b.Story(:refObjectName => "story", :ref => "http") {
	b.Tasks {
	  b.Task(:ref => "ref")
	  b.Task(:ref => "ref")
	  b.Task(:ref => "ref")
	}
      }
    end
    object.tasks.should be_instance_of(Array)
    object.tasks.length.should equal(3)
  end


  it "should lazy read from collections" do
    rest_builder = mock("RestBuilder")
    rest_builder.
      should_receive(:read_rest).
      twice.
      with(any_args()).
      and_return( xml do |b| 
		   b.Task { 
		     b.Name("name1")
		     b.Description("Description")
		   } 
		 end )

    @api = RallyRestAPI.new(:builder => rest_builder, :parse_collections_as_hash => false)

    object = rest_object_xml do |b|
      b.Story(:refObjectName => "story", :ref => "http") {
	b.Tasks {
	  b.Task(:refObjectName => "task1", :ref => "ref")
	  b.Task(:refObjectName => "task2", :ref => "ref")
	  b.Task(:refObjectName => "task3", :ref => "ref")
	}
      }
    end

    object.tasks.first.description.should == "Description"
    object.tasks.first.description.should == "Description"
    object.tasks.last.description.should == "Description"
  end
   
  it "should allow getting and setting rally_rest" do
    rally_rest = RallyRestAPI.new
	rest_object = RestObject.new
	rest_object.rally_rest = rally_rest
	rest_object.rally_rest.should equal(rally_rest)
  end

  it "should allow the type to be set" do
    rest_object = RestObject.new
	rest_object.type = :defect
	rest_object.type.should == :defect
  end

  it "should allow the name to be set" do
    rest_object = RestObject.new
	rest_object.name = "name"
	rest_object.name.should == "name"
  end

  it "should allow the setting and getting of any value" do
    rest_object = RestObject.new
	rest_object.description = "description"
	rest_object.description.should == "description"
  end

  it "should pass the type and set value to create on rally_rest" do
    builder = mock("builder")
	rally_rest = RallyRestAPI.new(:builder => builder)
	args = {:name => "name", :description => "description"}
    xml = %Q(<Object ref="bla" refObjectName="name">
               <Name>name</Name>
               <Description>description</Description>
             </Object>)

	builder.should_receive(:create_rest).with(:defect, args, nil, nil).and_return(xml)

    rest_object = RestObject.new
	rest_object.rally_rest = rally_rest
	rest_object.type = :defect
	rest_object.name = "name"
	rest_object.description = "description"
	rest_object.save!

    rest_object.ref.should == "bla"
	rest_object.name.should == "name"
    rest_object.description.should == "description"
  end
  
  it "should not try to save if there is no rally_rest" do
    rest_object = RestObject.new
	lambda { rest_object.save! }.should raise_error(StandardError, /missing RallyRestAPI instance/)
  end

  it "should not try to save if there is no type" do
    rally_rest = stub!("RallyRest")
    rest_object = RestObject.new(rally_rest)
	lambda { rest_object.save! }.should raise_error(StandardError, /missing object type/)
  end
end
