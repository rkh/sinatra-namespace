# Sinatra::Namespace

Adds namespaces to [Sinatra](http://sinatrarb.com). Allows namespaces to have local helpers.

## Features

### Nesting by prefix

    require "sinatra"
    require "sinatra/namespace"
    
    namespace '/blog' do
      get { haml :index }
    
      get '/:entry_id' do |id|
        @entry = Entry.find(id)
        haml :entry
      end
    end

### Nesting by condition

For example by host name:

    require "sinatra"
    require "sinatra/namespace"
    
    namespace :host_name => "www.example.com" do
      # ...
    end
    
    namespace :host_name => "api.example.com" do
      # ...
    end

Or any other condition routes support:

    require "sinatra"
    require "sinatra/namespace"
    
    namespace :agent => /Songbird/ do
      # ...
    end
    
    namespace :provides => :json do
      # ...
    end

Those can of course be combined, even with patterns:

    namespace '/api', :agent => /MyAgent/, :provides => :xml do
      # ...
    end

### Local helpers, filters and error handling

    require "sinatra"
    require "sinatra/namespace"
    
    helpers do
      def title
        "foo bar"
      end
      
      def posts
        Post.all
      end
    end
    
    get "/" do
      haml :index
    end
    
    namspace "/ruby" do
      before { @an_important_note = "filters work, too" }
      
      after do
        @an_important_note = nil # don't tell
      end
      
      not_found do
        "ruby does not know this ditty"
      end
      
      helpers do
        def posts
          super.where :topic => "ruby"
        end
      end
      
      get { haml :index }
      
      get "/new" do
        haml :new, {}, :object => Post.new(:topic => "ruby")
      end
    end

### With modules

Modular style (you can of course use the `namespace` method there, too):

    require "sinatra/base"
    require "sinatra/namespace"
    
    class Application < Sinatra::Base
      register Sinatra::Namespace
    
      def title
        "foo bar"
      end
      
      def posts
        Post.all
      end
      
      module RubyPosts
        # If you would have called that module Ruby, you would not have to set
        # your prefix by hand, ain't that cool, huh?
        prefix "/ruby"
        
        def posts
          super.where :topic => "ruby"
        end
        
        get { haml :index }

        get "/new" do
          haml :new, {}, :object => Post.new(:topic => "ruby")
        end
      end
    end

Wait, did that module turn into a namespace all by itself? No, actually it got turned into one by `Application` when it
tried to call `prefix`, which is not defined.

You can influence that behavior by setting `auto_namespace`:

    class Application < Sinatra::Base
      # enables auto namespacing, is default
      enable :auto_namespace
      
      # disables auto namespacing
      disable :auto_namespace
      
      # triggers auto namespaceing only on prefix and get
      set :auto_namespace, :only => [:prefix, :get]
      
      # triggers auto namespacing on all public methods of Sinatra::Namspace::NestedMethods except prefix
      set :auto_namespace, :except => :prefix
    end

So, how does one create a namespace from a module without that auto detection? Simple:

    Application.make_namespace SomeModule, :prefix => "/somewhere"


Installation
------------

    gem install sinatra-namespace

Alternatives
------------

Sinatra::Namespace is made for sharing some state/helpers.
If that is no what you are looking for, you have two alternative directions.

Simple prefixing, shares all state/helpers:

    require "sinatra"
    
    admin_prefix = "/this/is/the/admin/prefix"
    get(admin_prefix) { haml :admin_index }
    get("#{admin_prefix}/new_user") { haml :new_user }
    get("#{admin_prefix}/admin_stuff") { haml :admin_stuff }

Middleware, shares no state/helpers:

    require "sinatra/base"
    
    class Application < Sinatra::Base
      class AdminNamespace < Sinatra::Base
        get("admin/prefix") { haml :admin_index }
        get("admin/new_user") { haml :new_user }
        get("admin/admin_stuff") { haml :admin_stuff }
      end
      
      use AdminNamespace
    end
