require File.dirname(__FILE__) + '/rest_object'

# == An interface to the paged query result 
#
# QueryResult is a wrapper around the xml returned from a webservice
# query operation. A query could result in a large number of hits
# being returned, therefore the results are paged into page_size
# chunks (20 by default). QueryResult will seamlessly deal with the
# paging when using the #each iterator.
#
# === Example
#  rally = RallyRestAPI.new(...)
#  results = rally.find(:defect) { equal :name, "My Defects" }
#  results.each do |defect|
#    defect.update(:state => "Closed")
#  end
#
# 
class QueryResult < RestObject
  include Enumerable

  attr_reader :total_result_count
  attr_reader :page_size
  attr_reader :start_index

  def initialize(query, rally_rest, document_content)
    super(rally_rest, document_content)
    elements[:results] = case self.results
      when Array then self.results.flatten
      when Hash then self.results.values.flatten
      when nil then []
    end
                           
    @query = query

    @total_result_count = elements[:total_result_count].to_i
    @page_size = elements[:page_size].to_i
    @start_index = elements[:start_index].to_i
  end

  # fetch the next page of results. Uses the original query to generate the query string.
  def next_page
    @rally_rest.query(@query.next_page(:start => self.start_index + self.page_size,
				       :pagesize => self.page_size))
  end

  # Iteration all pages of the result
  def each
    current_result = self
    begin 
      last_result = current_result
      current_result.elements[:results].each do |result|
	# The collection of refs we are holding onto could grow without bounds, so dup
	# the ref
	yield result.dup
      end
      current_result = current_result.next_page if current_result.more_pages?
    end while !last_result.equal? current_result
  end

  # return the first element. Useful for queries that return only one result
  def first
    results.first
  end

  # The length of the current page of results
  def page_length
    return 0 if self.elements[:results].nil?
    self.elements[:results].length
  end

  # Are there more pages?
  def more_pages?
    return false if start_index == 0
    (self.start_index + self.page_length) -1 < self.total_result_count
  end

   protected
   def parse_collections_as_hash? # :nodoc:
     false
   end

  def ref?(element) # :nodoc:
    !element.nil? && 
      !element.attributes["ref"].nil?
  end

  def terminal?(node) # :nodoc:
    !node.has_elements? || ref?(node)
  end

end
