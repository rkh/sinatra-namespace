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
      
      module Ruby
        def posts
          super.where :topic => "ruby"
        end
        
        # '/ruby'
        get { haml :index }

        # '/ruby/new'
        get "/new" do
          haml :new, {}, :object => Post.new(:topic => "ruby")
        end
      end
      
      namespace '/admin' do
        # ...
      end
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
