require File.dirname(__FILE__) + '/../test_helper'
require 'test/unit'
require 'test/unit/testcase'


class QueryResultTestCase < Test::Unit::TestCase
  

  def setup
    @api = RallyRestAPI.new
  end

  def make_result(total, page_size, start_index)
    xml = %Q(<QueryResult><TotalResultCount>#{total}</TotalResultCount><PageSize>#{page_size}</PageSize><StartIndex>#{start_index}</StartIndex><Results>)
    page_size.times { |i| xml << %Q(<RefElement ref="http" refObjectName="name#{i}"/>) }
    xml << %Q(</Results></QueryResult>)
    xml
  end
  
  def test_basic_numbers
    result_xml = make_result(20, 20, 1)
    result = QueryResult.new(nil, @api, result_xml)
    assert_equal(20, result.total_result_count)
    assert_equal(20, result.page_size)
    assert_equal(1, result.start_index)
    assert_equal(20, result.page_length)
  end

  def test_more_pages_when_enpty
    query_result_xml = make_result(0, 0, 0)
    result = QueryResult.new(nil, @api, query_result_xml)
    assert(! result.more_pages?, "No more pages when results empty")
  end

  def test_more_pages_when_no_pages
    query_result_xml = make_result(20, 20, 1)
    result = QueryResult.new(nil, @api, query_result_xml)
    assert(! result.more_pages?, "No more pages when total == page size")
  end

  def test_more_pages_when_more_pages
    query_result_xml = make_result(21, 20, 1)
    result = QueryResult.new(nil, @api, query_result_xml)
    assert(result.more_pages?, "Should have more pages when total != page size")
  end

end
