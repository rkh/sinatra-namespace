Sinatra::Namespace
==================

Adds namespaces to [Sinatra](http://sinatrarb.com). Allows namespaces to have local helpers.

BigBand
-------

Sinatra::Namespace is part of the [BigBand](http://github.com/rkh/big_band) stack.
Check it out if you are looking for other fancy Sinatra extensions.

Usage
-----

Classic style:

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

Note how namespaces can have local helpers not available to the outer namespace but inherits the outer helpers.

Modular style (you can of course use the `namespace` method there, too):

    require "sinatra/base"
    require "sinatra/namespace"
    
    class Application < Sinatra::Base
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
tried to call `prefix`, which is not defined. `Sinatra::Namspace` sets up `nested_method_missing` (from `monkey-lib`) to
catch that cases.

You can influence that behavior by setting `auto_namespace`:

    class Application < Sinatra::Base
      # enables auto namespacing, is default
      enable :auto_namespace
      
      # disables auto namespacing, is default
      disable :auto_namespace
      
      # triggers auto namespaceing only on prefix and get
      set :auto_namespace, :only => [:prefix, :get]
      
      # triggers auto namespacing on all public methods of Sinatra::Namspace::NestedMethods except prefix
      set :auto_namespace, :except => :prefix
    end

So, how does one create a namespace from a module without that auto detection? Simple:

    Application.make_namespace SomeModule, :prefix => "/somewhere"
