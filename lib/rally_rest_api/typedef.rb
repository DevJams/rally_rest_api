require 'pp'
class TypeDefinition < RestObject # :nodoc:

  def self.cached_type_definitions
    @@cached_type_definitions ||= {}
  end

  def self.cached_type_definition(workspace_domain_object, type = workspace_domain_object.type)
    key = make_key(workspace_domain_object.workspace, type)

    unless cached_type_definitions.key? key
      cached_type_definitions[key] = get_type_definition(workspace_domain_object.workspace, type)
    end
    cached_type_definitions[key]
  end

  def self.get_type_definition(workspace, type)
    get_type_definitions(workspace).find { |td| td.element_name == type }
  end

  def self.get_type_definitions(workspace)
    # This is a hack - having to do with parse_collections_as_hash?
    typedefs = case workspace.type_definitions
               when Hash then workspace.type_definitions.values.flatten
               when Array then workspace.type_definitions
	       end
    # end hack  
    typedefs.map { |td| TypeDefinition.new(td.rally_rest, td.body) }
  end

  def self.make_key(workspace, type)
    # Parent typedefs don't have a workspace, so key them appropriately
    ref = workspace.ref rescue ""
    type + ref
  end

  def custom_attributes
    collect_attributes { |element_name, attrdef| attrdef.custom == "true" }
  end

  # custom and constrained, i.e. a custom dropdown
  def custom_constrained_attributes
    collect_attributes { |element_name, attrdef| attrdef.custom == "true" && attrdef.constrained == "true" }
  end
  alias custom_dropdown_attributes custom_constrained_attributes 

  def constrained_attributes
    collect_attributes { |element_name, attrdef| attrdef.constrained == "true" }
  end

  def collection_attributes(include_parent = false)
    collect_attributes(include_parent) { |element_name, attrdef| attrdef.attribute_type == "COLLECTION" }
  end

  def object_attributes(include_parent = false)
    collect_attributes(include_parent) { |element_name, attrdef|  attrdef.attribute_type == "OBJECT" }
  end

  def reference_attributes(include_parent = false)
    collection_attributes(include_parent).merge object_attributes(include_parent)
  end

  def collect_attributes(include_parent = false)
    values = self.attributes(include_parent).find_all { |element_name, attrdef| yield element_name, attrdef }
    Hash[*values.flatten]
  end

  def symbol_keyed_attributes(attribute_hash)
    return {} unless attribute_hash  # some typedefs will have no attributes
    attribute_hash.values.inject({}) do |hash, attrdef|
      hash[underscore(attrdef.element_name).intern] = AttributeDefinition.new(self.rally_rest, attrdef)
      hash
    end
  end

  def attributes(include_parent = false)
    return symbol_keyed_attributes(self.elements[:attributes]) unless include_parent

    typedef = self
    all_attributes = {}
    until typedef.nil?
      all_attributes.merge! typedef.attributes(false)
      typedef = typedef.parent
    end
    all_attributes
  end

  def parent
    return nil if self.elements[:parent].nil?
    cached_parent
  end

  def cached_parent
    type_no_spaces = self.elements[:parent].name.gsub(" ", "")
    key = TypeDefinition.make_key(self.workspace, type_no_spaces)
    typedef = TypeDefinition.cached_type_definitions[key]
    if typedef.nil?
      typedef = TypeDefinition.cached_type_definitions[key] = TypeDefinition.new(self.rally_rest, self.elements[:parent].body)
    end
    typedef
  end

  def type_as_symbol
    underscore(element_name).intern
  end

  protected
  def parse_collections_as_hash?
    true
  end
  
end
