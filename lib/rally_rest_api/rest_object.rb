require 'logger'
require File.dirname(__FILE__) + '/rest_builder'
require 'builder/blankslate'
require 'forwardable'

# == An interface to a Rally resource
# RestObject is an adapter that is initialized with a resource ref (URL) that represents a Rally object. The adapter
# is responsible for reading the full XML representation and providing a clean API for accessing the elements of the
# XML. 
#
# Additionally, the RestObject adapter can #update and #delete the underlying resource.
#
# When resources have elements that are collections of other objects, then the collection will be 
# represented as a Hash of elements, unless those elements do not carry name attributes (such as cards in Use Case Mode). 
# In the case of collections of object that have no name, the collection of objects will be an array. NOTE: this may
# change in the future.
#
# RestObjects are aware of the RallyRestAPI that they were accessed through. All further read, update and delete operations
# will be carried out as the same user as their RallyRestAPI.
#
#

class FancyHash < Hash # :nodoc: all
  def method_missing(sym, *args)
    self[sym]
  end
end

class RestObject
  extend Forwardable

  attr_accessor :rally_rest
  def_delegator(:rally_rest, :username)
  def_delegator(:rally_rest, :password)

  def initialize(rally_rest = nil, document_content = nil)
	@changed_values = {} 
    @rally_rest = rally_rest
    @document_content = document_content
    parse_document if document_content
  end

  def parse_document
    @document = REXML::Document.new @document_content
    if !ref?(@document.root)
      @elements = parse(@document.root)
    else 
      @elements = nil
    end
  end

  def marshal_dump
    [@rally_rest, @document_content, @changed_values]  
  end

  def marshal_load(stuff)
    @rally_rest, @document_content, @changed_values = *stuff
    parse_document
  end
  
  private
  def terminal?(node)
    !node.has_elements?
  end

  def terminal_object(node)
    if ref?(node)
      low_debug  "Returning RestObject for #{ node.to_s}"
      return RestObject.new(rally_rest, node.to_s)
    else
      low_debug  "Returning text #{ node.text }"
      return node.text
    end
  end

  def parse(node)
    low_debug  "parse self = #{self.object_id} node = #{ node.to_s }"

    if terminal? node
      return terminal_object(node)
    end

    # Convert nodes with children into Hashes
    elements = FancyHash.new

    #Add all the element's children to the hash.
    node.each_element do |e|
      name = underscore(e.name).to_sym
      low_debug  "Looking at name = #{ name }"
      case elements[name]
	# We've not seen this element before
      when NilClass
	low_debug  "NilClass name = #{ name }"
	# if we have a collection of things with refObjectName attributes, collect them into a hash 
	# with the refObjectName as the key, unless we're told not to make hashs out of collections.
	if named_collection?(e) && parse_collections_as_hash?
	  low_debug  "Named collection #{ name }"
	  elements[name] = {}
	  e.elements.each do |child|
	    ref_name = child.attributes["refObjectName"]
	    if elements[name][ref_name]
	      elements[name][ref_name] = [elements[name][ref_name]] unless elements[name][ref_name].kind_of? Array
	      elements[name][ref_name] << parse(child)
	    else
	      elements[name][ref_name] =  parse(child)
	    end
	  end
	elsif collection?(e)
	  low_debug  "Collection #{ name }"
	  elements[name] = []
	  e.elements.each do |child|
	    elements[name] << parse(child)
	  end
	else # a fully dressed object, without a name
	  low_debug  "Fully Dressed object, without a name #{ name }"
	  elements[name] = parse(e)
	end

	#Non-unique child elements become arrays: We've already
	#created the array: just add the element.
      when Array
	low_debug  "Array name = #{ name }"
	elements[name] << parse(e)

	#We haven't created the array yet: do so,
	#then put the existing element in, followed
	#by the new one.
#      when Hash
#	raise "Don't know how to deail with a named collection we've already seen! element = #{e}"
      else
	low_debug  "creating and wrapping #{elements[name]}with an array name = #{ name }"
	elements[name] = [elements[name]]
	elements[name] << parse(e)
      end
    end
    return elements
  end

  public

  def underscore(camel_cased_word)
    camel_cased_word.split(/(?=[A-Z])/).join('_').downcase
  end

  # return the XML of the resource
  def body
    @document.to_s
  end

  # the resource's URI
  def ref
    @document.root.attributes["ref"]
  end
  alias :to_q :ref

  # The name of the object, without having to read the entire body
  def name
    @changed_values[:name] || @document.root.attributes["refObjectName"]
  end
  alias :to_s :name

  # The type of the underlying resource
  def type
    @type || @document.root.attributes["type"] || @document.root.name
  end

  def type=(type)
  	@type = type
  end
  alias :artifact_type= :type=

  # the type as symbol
  def type_as_symbol
    underscore(self.type).intern
  end

  # The oid of the underlying resource
  def oid
    self.elements[:object_i_d]
  end

  # return the typedef for this resource. 
  def typedef
    # this is a little ugly as we start to introduce some type specific info into this class.    
    # All WorkspaceDomainObjects have a #workspace, that excludes user, workspace and subscription. 
    return nil if self.type =~ /User|Workspace|Subscription/
    TypeDefinition.cached_type_definition(self)
  end

  # re-read the resource
  def refresh
    self.elements(true)
    self
  end

  def elements(read = @elements.nil?) #:nodoc:
    if read
      @document_content = builder.read_rest(self.ref, username, password)
      @document = REXML::Document.new @document_content
      @elements = parse(@document.root)
    end
    @elements
  end

  def ==(object)
    object.equal?(self) ||
      (object.instance_of?(self.class) &&
       object.ref == ref)
  end

  def hash
    ref.hash
  end
  
  def eql?(object)
    self == (object)
  end

  def <=>(object)
    self.ref <=> object.ref
  end

  public 

  def save!
    raise 'missing RallyRestAPI instance' unless rally_rest
    raise 'missing object type' unless @type
	@document_content = builder.create_rest(type, @changed_values, username, password)
    parse_document
  end
  
  # update the resource. This will re-read the resource after the update
  def update(args)
    builder.update_rest(type, ref, args, username, password)
    self.elements(true)
  end

  # delete the resource
  def delete
    builder.delete_rest(ref, username, password)
  end

  def method_missing(sym, *args) # :nodoc:
    method = sym
    if sym.to_s.match(/(.*)=$/)
	  method = $1.intern 
	  return @changed_values[method] = args.first
	end

    @changed_values[method] || self.elements[method]
    # Sometimes the xml returned has no element for things that are simply null. Without
    # asking the typedef, I have no way to know if the element exists, or has been ommited.
    # It would not be hard to ask the typedef, but they are expensive to load. It should be an option
  end


  protected 
  def named_collection?(element) # :nodoc:
    collection?(element) && element.elements.find_all { |e| e.attributes['ref'] && e.attributes['refObjectName'] }.length > 0
  end

  def unnamed_collection?(element) # :nodoc:
    collection?(element) && element.elements.find_all { |e| e.attributes['ref'] && e.attributes['refObjectName'] == nil }.length > 0
  end

  def collection?(element) # :nodoc:
    !element.has_attributes? && element.has_elements? && element.elements.find_all { |e| e.attributes['ref'] }.length == element.elements.size
  end

  def ref?(element) # :nodoc:
    !element.nil? && 
      !element.has_elements? && 
      !element.attributes["ref"].nil?
  end

  def parse_collections_as_hash? # :nodoc:
    self.rally_rest.parse_collections_as_hash?
  end

  def low_debug(message)
    # debug message
  end
  
  def debug(message) 
     @rally_rest.logger.debug(message) if @rally_rest.logger
  end

  def builder
    rally_rest.builder
  end
end
