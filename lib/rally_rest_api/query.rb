require 'uri'

class String # :nodoc: all
  def to_camel(downcase_first_letter = false)
    word = self.split(/\./).map { |word| word.split(/_/).map { |word| word.capitalize }.join}.join('.')
  end
  
  alias :to_q :to_s
end

class Fixnum # :nodoc: all
  alias :to_q :to_s
end

class Symbol # :nodoc: all
  def to_q
    self.to_s.to_camel
  end
end

class NilClass # :nodoc: all
  def to_q
    "null"
  end
end

class TrueClass # :nodoc: all
  alias :to_q :to_s
end

class FalseClass # :nodoc: all
  alias :to_q :to_s
end

# == Generate a query string for Rally's webservice query interface.
# Arguments are:
#  type - the type to query for
#  args - arguments to the query. Supported values are
#  :pagesize => <number> - The number of results per page. Max of 100
#  :start => <number> - The record number to start with. Assuming more then page size records.
#  :fetch => <boolean> - If this is set to true then entire objects will be returned inside the query result. If set to false (the default) then only object references will be returned.
#  :workspace - If not present, then the query will run in the user's default workspace. If present, this should be the RestObject containing the workspace the user wants to search in.
#  :project - If not set, or specified as "null" then the "parent project" in the given workspace is used. If set, this should be the RestObject containing the project. Furthermore, if set you may omit the workspace parameter because the workspace will be inherited from the project.
#  :project_scope_up - Default is true. In addition to the specified project, include projects above the specified one.
#  :project_scope_down - Default is true. In addition to the specified project, include child projects below the current one.
#  &block - the query parameters
#
# === The query parameters block
#
# The query parameters block is a DSL the specifying the query parameters. Single attribute specifiers are
# written in prefix notation in the form:
#  <operator> <attribute symbol>, <value>
# for example
#  equal :name, "My Name"
# Allowed operators and their corresponding generated query strings are:
#    equal              => "="
#    not_equal          => "!="
#    contains           => "contains"
#    greater_than       => ">"
#    gt                 => ">"
#    less_than          => "<"
#    lt                 => "<"
#    greater_than_equal => ">="
#    gte                => ">="
#    less_then_equal    => "<="
#    lte                => "<="
# 
# == Boolean logic.
#
# By default, if more then one query parameter is specified in the block, then those parameters will be ANDed together.
# For example, if the query parameter block contains the follow expression:
#  equal :name, "My Name"
#  greater_than :priority, "Fix Immediately"
# these expressions will be ANDed together. You may specify explicit AND and OR operators using the 
# _and_ and _or_ operators, which also accept parameter blocks. For example the above expression could also have 
# been written:
#  _and_ {
#    equal :name, "My Name"
#    greater_than :priority, "Fix Immediately"
#  }
# \_or_ works in the same fashion. _and_s and _or_s may be nested as needed. See the test cases for RestQuery for
# more complex examples
#
# If you have ruport installed, you may also call to_table on a QueryResult to convert the result to a Ruport::Data:Table
#
class RestQuery
  attr_reader :type

  def initialize(type, args = {}, &block)
    @type = type
    @query_string = "query=" << URI.escape(QueryBuilder.new("and", &block).to_q) if block_given?
    @query_string.gsub!("&", "%26")
    @args_for_paging = {}
    [:workspace, :project, :project_scope_down, :project_scope_up, :order, :fetch].each { |k| @args_for_paging[k] = args[k] if args.key?(k) }
    @query_params = process_args(args)
  end

  def process_args(args) # :nodoc:
    return if args.nil?
    query_string = ""
    args.each do |k, v|
      case k
      when :order
	# this is a hack, we need a better way to express descending
	v = [v].flatten.map { |e| e.to_s.to_camel }.join(", ").gsub(", Desc", " desc")
      when :fetch
        raise "value for fetch must be either true or false" unless v.to_q == "true" || v.to_q == "false"         
      end
      key = de_underscore(k)
      query_string << "&#{key}=#{URI.escape(v.to_q)}"
    end
    query_string
  end

  def next_page(args)
    @query_params = process_args(args.merge(@args_for_paging))
    self
  end

  def to_q
    "#{@query_string}#{@query_params}"
  end

  def self.query(&block)
    QueryBuilder.new("and", &block).to_q
  end

  private 
  def de_underscore(s)
    words = s.to_s.split(/_/).map { |w| w.capitalize }
    words[0].downcase!
    words.join
  end
end

# Internal support for generating query string for the Rally Webservice.
# See RestQuery for examples.
class QueryBuilder # :nodoc: all
  attr_reader :operator

  # Define the operators on the query terms. I've include perl-like operators for 
  # less_than and greater_then etc.
  { 
    :equal              => "=",
    :not_equal          => "!=",
    :contains           => "contains",
    :greater_than       => ">",
    :gt                 => ">",
    :less_than          => "<",
    :lt                 => "<",
    :greater_than_equal => ">=",
    :gte                => ">=",
    :less_then_equal    => "<=",
    :less_than_equal    => "<=",
    :lte                => "<=",
  }.each do |method, operator|
    module_eval     %{def #{method}(lval, rval)
                       rval = \"\\"\#{rval}\\"\" if rval =~ / /
                       add(QueryString.new(lval, \"#{operator}\", rval), @operator)
                      end}
  end


  def initialize(operator, &block)
    @operator = operator
    instance_eval(&block)
  end

  def _and_(&block)
    add(QueryBuilder.new("and", &block), @operator)
  end
  
  def _or_(&block)
    add(QueryBuilder.new("or", &block), @operator)
  end
  
  def add(new_value, op)
    if value.empty?
      value.push new_value
    else  
      value.push QueryString.new(value.pop, op, new_value)  
    end
    self
  end
  
  def value
    @value ||= []
  end

  def to_q
    value[0].to_q
  end

end

class QueryString # :nodoc: all
  def initialize(lhs, op, rhs)
    @lhs, @op, @rhs = lhs, op, rhs
  end

  def to_q
    "(#{@lhs.to_q} #{@op.to_q} #{@rhs.to_q})"
  end
end
