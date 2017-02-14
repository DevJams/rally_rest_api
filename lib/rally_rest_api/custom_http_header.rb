class CustomHttpHeader
  attr_accessor :name, :version, :vendor
  attr_reader :library, :os, :platform

  HTTP_HEADER_FIELDS = [:name, :vendor, :version, :library, :platform, :os]
  HTTP_HEADER_PREFIX = 'X-RallyIntegration'

  def initialize
    @os = RUBY_PLATFORM
    @platform = "Ruby #{RUBY_VERSION}"
    @library = "RallyRestAPI version #{RallyRestVersion::LIBRARY_VERSION::STRING}"
    @name = "RubyRestAPI"
  end

  def add_headers(req)
    headers = {}
    HTTP_HEADER_FIELDS.each do |field|
      value = self.send(field)
      next if value.nil?
      req.add_field("#{HTTP_HEADER_PREFIX}#{field.to_s.capitalize}", value)
    end
  end
end
