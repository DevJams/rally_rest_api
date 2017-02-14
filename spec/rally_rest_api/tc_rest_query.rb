require File.dirname(__FILE__) + '/../test_helper'

class TestRestQuery < Test::Unit::TestCase
  # RestQuery.find(:feature).where {  # default is and
  #   equal :name, "name"  
  #   or {
  #     equal :name, "name"
  #     equal :card.task.name, "task name"
  #     less_than :plan_estimate, "10"
  #   }
  # }
  def test_single_statement
    assert_equal("(Name = name)", RestQuery.query { equal :name, "name"} )
  end

  def test_name_with_spaces
    assert_equal("(Name = \"name name\")", RestQuery.query { equal :name, "name name"} )
  end

  def test_null_parameter
    assert_equal("(Name = null)", RestQuery.query { equal :name, nil} )
  end
  
  def test_attribute_camelized
    assert_equal("(IterationName != iteration)", 
    RestQuery.query { not_equal :iteration_name, "iteration"}
    )
  end
  
  def test_attribute_path_camelized
    assert_equal("(Card.IterationName contains iteration)", 
    RestQuery.query{ contains :'card.iteration_name', "iteration"} 
    )
  end
  
  def test_multiple_and_statements
    assert_equal("((Name = name) and (Description > description))", 
    RestQuery.query do
      equal :name, "name"
      greater_than :description, "description"
    end
    )
    
    assert_equal("(((Name = name) and (Description = description)) and (Notes <= notes))", 
    RestQuery.query do
      equal :name, "name"
      equal :description, "description"
      lte :notes, "notes"
    end
    )
  end

  def test_multiple_or_statements
    assert_equal("((Name = name) or (Description >= description))", 
    RestQuery.query do
      _or_ do
        equal :name, "name"
        gte :description, "description"
      end
    end
    )
  end
  
  def test_multiple_ands_with_or
    assert_equal("(((Name = name) and (Description >= description)) or (Notes = notes))",
    RestQuery.query do
      _or_ do      
        _and_ do
          equal :name, "name"
          greater_than_equal :description, "description"
        end
        equal :notes, "notes"
      end
    end
    )
  end
  
  def test_multiple_ors_with_and
    assert_equal("(((Name = name) or (Description = description)) and (Notes = notes))",
    RestQuery.query do
      _or_ do
        equal :name, "name"
        equal :description, "description"
      end
      equal :notes, "notes"
    end
    )
  end
  
  def test_multiple_ors_with_multiple_ands
    assert_equal("(((Name = name) or (Description = description)) and ((Notes = notes) and (StartDate = start)))",
    RestQuery.query do
      _or_ do
        equal :name, "name"
        equal :description, "description"
      end
      _and_ do
        equal :notes, "notes"
        equal :start_date, "start"
      end
    end
    )
  end
  
  def test_three_ors_with_three_ands
    assert_equal("((((Name = name1) or (Description = description1)) or (Other = other1)) and (((Notes = notes2) and (StartDate = start2)) and (Other = other2)))",
    RestQuery.query {
      _and_ {
        _or_ {
          equal :name, "name1"
          equal :description, "description1"
          equal :other, "other1"
        }
        _and_ {
          equal :notes, "notes2"
          equal :start_date, "start2"
          equal :other, "other2"
        }
      }
    }
    )
  end
  
  def test_anded_ors
    assert_equal("(((Name = name1) or (Name = name2)) and ((Name = name3) or (Name = name4)))", 
    RestQuery.query do
      _or_ do
        equal :name, "name1"
        equal :name, "name2"
      end
      _or_ do
        equal :name, "name3"
        equal :name, "name4"
      end
    end
    )
  end

  def test_new_with_type_no_args
    query_string = RestQuery.new(:artifact) { equal :name, "name"}.to_q
    assert_equal("query=(Name = name)", URI.unescape(query_string) )    
  end

  def test_new_with_type_and_args
    query_string = RestQuery.new(:artifact, 
				 :pagesize => 10, 
				 :start => 1) { equal :name, "name"}.to_q

    # The parameters sometimes appear in a different order
    unescaped_qs = URI.unescape(query_string)
    assert(unescaped_qs =~ /&start=1/)
    assert(unescaped_qs =~ /&pagesize=10/)
    assert(unescaped_qs =~ /query=\(Name = name\)/)
    # assert_equal("query=(Name = name)&pagesize=10&start=1", URI.unescape(query_string) )
  end

  def test_new_with_one_order_arg
    query_string = RestQuery.new(:artifact, 
				 :order => :package) { equal :name, "name"}.to_q
    assert_equal("query=(Name = name)&order=Package", URI.unescape(query_string) )
  end

  def test_new_with_multiple_order_arg
    query_string = RestQuery.new(:artifact, 
				 :order => [:package, :owner]) { equal :name, "name"}.to_q
    assert_equal("query=(Name = name)&order=Package, Owner", URI.unescape(query_string) )
  end

  def test_new_with_multiple_order_arg_desc
    query_string = RestQuery.new(:artifact, 
				 :order => [:package, :owner, :desc]) { equal :name, "name"}.to_q
    assert_equal("query=(Name = name)&order=Package, Owner desc", URI.unescape(query_string) )
  end

  def test_new_with_true_fetch_arg
    query_string = RestQuery.new(:artifact, 
				 :fetch => true) { equal :name, "name"}.to_q
    assert_equal("query=(Name = name)&fetch=true", URI.unescape(query_string) )
  end

  def test_new_with_false_fetch_arg
    query_string = RestQuery.new(:artifact, 
				 :fetch => false) { equal :name, "name"}.to_q
    assert_equal("query=(Name = name)&fetch=false", URI.unescape(query_string) )
  end

  def test_new_with_options_with_underscores
    query_string = RestQuery.new(:artifact, 
				 :project_scope_up => false) { equal :name, "name"}.to_q
    assert_equal("query=(Name = name)&projectScopeUp=false", URI.unescape(query_string) )
  end


  def test_next_page
    q = RestQuery.new(:artifact, 
		      :pagesize => 10, 
		      :start => 1) { equal :name, "name"}
    query_string = q.to_q

    # The parameters sometimes appear in a different order
    unescaped_qs = URI.unescape(query_string)
    assert(unescaped_qs =~ /&start=1/)
    assert(unescaped_qs =~ /&pagesize=10/)
    assert(unescaped_qs =~ /query=\(Name = name\)/)
    # assert_equal("query=(Name = name)&pagesize=10&start=1", URI.unescape(query_string) )
    query_string = q.next_page(:pagesize => 20,
			       :start => 20).to_q

    # The parameters sometimes appear in a different order
    unescaped_qs = URI.unescape(query_string)
    assert(unescaped_qs =~ /&start=20/)
    assert(unescaped_qs =~ /&pagesize=20/)
    assert(unescaped_qs =~ /query=\(Name = name\)/)
    # assert_equal("query=(Name = name)&pagesize=20&start=20", URI.unescape(query_string) )
  end

  
end
