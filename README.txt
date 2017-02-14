rally-rest-api -- A Ruby-ized interface to Rally's REST webservice API

==Introduction:
Rally Software Development's on-demand agile software life-cycle management service offers webservices API's for its customers. The API comes in both SOAP and REST style interfaces. This library is for accessing the REST API using Ruby. For more information about Rally's webservice APIs see https://rally1.rallydev.com/slm/doc/webservice/index.jsp.

This API provides full access to all CRUD operations and a rich interface to the query facility. An Enumerable interface is provided for the paginated query results.

== Rationale (i.e. Why not SOAP?):
Your subscription in Rally can be partitioned into several isolated "Workspaces", where the only thing shared between workspaces are your users. Any custom attributes you create will be specific to each workspace. When using the SOAP interface, the WSDL generated is specific to the workspace you are working in. Therefore the name-space (e.g. package in Java) will be different for each workspace you are working with.

Because REST webservices do not have WSDL (the XML schema is available for each workspace), there is no per-workspace interface. Combined with the dynamic nature of this API, you don't need to code to different Ruby namespaces when you are working with multiple workspaces. You will, however, need to be aware of the workspaces your objects are in when working with multiple workspaces.

== Getting Started:
RallyRestAPI is the entry point to the api. Each instance corresponds to one user logged into Rally. There are several options that may be passed to the constructor:
    :username         => Your Rally login username.
    :password         => Your Rally login password. Username and password will be remembered by this 
                         instance of the API and all objects created and read by this instance.
    :base_url         => The base url for the system you are talking to. Defaults to https://rally1.rallydev.com/slm/
    :logger           => A logger to log to. There is interesting logging info for DEBUG and INFO
    :builder	      => A builder is the Class responsible for the HTTP level protocol. Defaults to RestBuilder
    :version	      => The version of the API you want to talk to. Defaults to "current"

== Rest Object:
All rally resources referenced by the api are of type RestObject, there only a few subclasses. In its initial form a RestObject is just a URL representing a resource. This URL is accessed using RestObject#ref. When more information is requested about the object, the API will read the content of that resource. This read is done lazily and transparently.

RestObject makes heavy use of method_missing to achieve its dynamism. The XML for each resource is parsed into a nested Hash where the keys of the Hash are the Ruby-ized Elements names of the XML, and the values of the hash are the string values of the elements, or other RestObjects (in the case of references between objects), or collections of both. This allows the API to respond to chained method invocations like:

  rally.user.subscription.workspaces.first.projects.first.iterations.first.name

Traversals across object references (RestObjects) cause a lazy read of that resource.

When establishing object relationships between objects, during create or update, they are done using RestObjects. For example, to associate a user story to a defect, you would use the 'requirement' association on defect to reference the User Story. Here 'defect' and 'user_story' already exist, and the variables contain RestObjects representing them:

  defect.update(:requirement => user_story)

== CRUD and Query:

Given an instance of the RallyRestAPI:

      rally = RallyRestAPI.new(:username => <username>,
                               :password => <password>)

=== Create: 

RallyRestAPI#create(<rally artifact type>, <artifact attributes as a hash>) returns a RestObject:

    defect = rally.create(:defect, :name => "Defect name")

#create will also accept a block, and yield the newly created reference to the block

    rally.create(:defect, :name => "Defect name") do |defect|
      # do something with defect here
    end

The block form is useful for creating relationships between objects in a readable way. For example, to create a User Story (represented by the type HierarchicalRequirement) with a task:

    rally.create(:hierarchical_requirement, :name => "User Story One", :iteration => iteration_one) do |user_story|
      rally.create(:task, :name => "Task One", :work_product => user_story)
    end

The above example will create a UserStory, pass it to the block, then create a Task on that User Story using the task's 'WorkProduct' relationship.

=== Read:
As mentioned above, RestObject will lazy read themselves on demand. If you need to force a RestObject to re-read itself, call RestObject#refresh. 

=== Update:
There are two ways to update an object:

    RallyRestAPI#update(<rest object>, <attributes>)
    RestObject#update(<attributes>)

which is to say, a RestObject can update itself

    defect.update(:name => "new name")

Or the rest api can update it:

    rally.update(defect, :name => "new name")

=== Delete:
There are two ways to delete an object:

    RallyRestAPI#delete(<rest object>)
    RestObject#delete

which is to say, a RestObject can delete itself

    defect.delete

Or the rest api can delete it:

    rally.delete(defect)

=== Query:
RallyRestAPI#find is the interface to the query syntax of Rally's webservice APIs.  The query interface in Ruby provides full support for this query syntax including all the operators. A quick example:

    query_result = rally.find(:defect) { equal :name, "Defect name" }

In addition to the type, #find accepts other arguments as a hash:

  :pagesize => <number> - The number of results per page. Max of 100
  :start => <number> - The record number to start with. Assuming more than page size records.
  :fetch => <boolean> - If this is set to true then entire objects will be returned inside the query 
   result. If set to false (the default) then only object references will be returned. Fetching full 
   objects will prevent another read when utilizing the results.
  :workspace - If not present, then the query will run in the user's default workspace. If present, 
   this should be the RestObject containing the workspace the user wants to search in.
  :project - If not set, or specified as "null" then the "parent project" in the given workspace is used. 
   If set, this should be the RestObject containing the project. Furthermore, if set you may omit the workspace 
   parameter because the workspace will be inherited from the project.
  :project_scope_up - Default is true. In addition to the specified project, include projects above the specified one.
  :project_scope_down - Default is true. In addition to the specified project, include child projects below the current one.

The return from #find is always a QueryResult. The QueryResult provides an interface to the paginated query result.

  #each will iterate all results on all pages.
  #total_result_count is the number of results for the whole query.
  #page_length is the number of elements in the current page of result. 
  #results returns an Array for the current page of results. 

Because of the paginated nature of the result list, deleting elements while using #each is undefined.

If you have Ruport installed (http://www.rubyreports.org), QueryResult will have a #to_table method included. #to_table takes an array of symbols that define the columns in the table:

  defects = rally.find(:defect, :fetch => true) { equal :state, "Open }
  table = defects.to_table([:name, :severity, :priority, :owner])
  table.to_pdf

See rubyreports.org for more information about creating reports with Ruport.

See the rdoc for RestQuery for more query examples.
