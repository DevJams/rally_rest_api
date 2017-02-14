require File.dirname(__FILE__) + '/rest_object'

class AttributeDefinition < RestObject # :nodoc:

  def initialize(rally_rest, values)
    super(rally_rest)
    @elements = values
  end

  # return the XML of the resource
  def body
    nil
  end

  # the resource's URI
  def ref
    nil
  end

  # The name of the object, without having to read the entire body
  def name
    @elements[:name]
  end

  # The type of the underlying resource
  def type
    "AttributeDefinition"
  end

  def allowed_values
    self.elements[:allowed_values].map {|e| e[:string_value] }
  end
end
