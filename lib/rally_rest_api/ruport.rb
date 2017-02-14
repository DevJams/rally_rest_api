# Add Ruport (http://rubyreports.org/) support to the RallyRestAPI.
# This will add a method, #to_table, to QueryResult
#
# For example:
#  table = rally_api.find(:defect) { equal :state, "Open" }.to_table([:formatted_i_d, :name, :owner])
#  table.to_pdf
#

# Ruport can deal with anything that has a #to_hash
class RestObject
  def to_hash # :nodoc
    elements
  end
end

class QueryResult
  # return a Ruport::Data::Table. Takes an array of columns for the report
  #    defects = rally.find(:defect, :fetch => true) { equal :state, "Open }
  #    table = defects.to_table([:name, :severity, :priority, :owner])
  #    table.to_pdf
  def to_table(columns = [])
    table = Ruport::Data::Table.new(:column_names => columns)
    self.each { |i| table << i }
    table
  end
end
