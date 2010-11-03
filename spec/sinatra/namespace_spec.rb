require File.expand_path("../../spec_helper", __FILE__)

describe Sinatra::Namespace do
  it_should_behave_like 'sinatra'

  it "should delegate namespace" do
    Sinatra::Delegator.private_instance_methods.map(&:to_s).should include("namespace")
  end

  [:get, :head, :post, :put, :delete].each do |verb|
    describe "HTTP #{verb.to_s.upcase}" do
      before :each do
        Object.send :remove_const, :App if Object.const_defined? :App
        class ::App < Sinatra::Base
          register Sinatra::Namespace
        end
        app App
      end

      describe :namespace do
        it "should add routes including prefix to the base app" do
          app.namespace "/foo" do
            send(verb, "/bar") { "baz" }
          end
          browse_route(verb, "/foo/bar").should be_ok
          browse_route(verb, "/foo/bar").body.should == "baz" unless verb == :head
        end

        it "should allows adding routes with no path" do
          app.namespace "/foo" do
            send(verb) { "bar" }
          end
          browse_route(verb, "/foo").should be_ok
          browse_route(verb, "/foo").body.should == "bar" unless verb == :head
        end

        it "allows nesting" do
          app.namespace "/foo" do
            namespace "/bar" do
              namespace "/baz" do
                send(verb) { 'foobarbaz' }
              end
            end
          end
          browse_route(verb, "/foo/bar/baz").should be_ok
          browse_route(verb, "/foo/bar/baz").body.should == "foobarbaz" unless verb == :head
        end

        it "allows regular expressions" do
          app.namespace %r{/\d\d} do
            send(verb) { "foo" }
            namespace %r{/\d\d} do
              send(verb) { "bar" }
            end
            namespace "/0000" do
              send(verb) { "baz" }
            end
          end
          browse_route(verb, '/20').should be_ok
          browse_route(verb, '/20').body.should == "foo" unless verb == :head
          browse_route(verb, '/20/20').should be_ok
          browse_route(verb, '/20/20').body.should == "bar" unless verb == :head
          browse_route(verb, '/20/0000').should be_ok
          browse_route(verb, '/20/0000').body.should == "baz" unless verb == :head
          browse_route(verb, '/20/200').should_not be_ok
        end
      end

      describe :filters do
        it 'should trigger before filters for namespaces' do
          app.before { settings.set :foo, 0 }
          app.namespace('/foo') do
            before { settings.set :foo, settings.foo + 1 }
            send(verb) { }
          end
          browse_route(verb, '/foo').should be_ok
          app.foo.should == 1
        end
        it 'should trigger after filters for namespaces' do
          $foo = 0
          app.after { $foo += 2 }
          app.namespace('/foo') do
            after { $foo += 1 }
            send(verb) { }
          end
          browse_route(verb, '/foo').should be_ok
          $foo.should == 3
        end
      end

      describe :make_namespace do
        it "extends modules make_namespace is called on" do
          mod = Module.new
          mod.should_not respond_to(verb)
          app.make_namespace(mod, :prefix => "/foo")
          mod.should respond_to(verb)
        end

        it "returns the module" do
          mod = Module.new
          app.make_namespace(mod, :prefix => "/foo").should == mod
        end

        it "sets base" do
          app.make_namespace(Module.new, :prefix => "/foo").base.should == app
        end

        it "sets prefix" do
          app.make_namespace(Module.new, :prefix => "/foo").prefix.should == "/foo"
        end

        it "automatically sets a prefix based on module name if none is given" do
          # FooBar = Module.new  <= does not work in Ruby 1.9
          module ::FooBar; end
          app.make_namespace ::FooBar
          ::FooBar.prefix.should == "/foo_bar"
        end

        it "does not add the application name to auto-generated prefixes" do
          #App::FooBar = Module.new <= does not work in Ruby 1.9
          class ::App < Sinatra::Base; module FooBar; end; end
          app.make_namespace App::FooBar
          App::FooBar.prefix.should == "/foo_bar"
        end
      end

      describe :auto_namespace do
        before do
          class ::App < Sinatra::Base; module Foo; end; end
        end

        it "detects #{verb}" do
          App::Foo.should_not respond_to(verb)
          App::Foo.send(verb, "/bar") { "baz" }
          App::Foo.should respond_to(verb)
          browse_route(verb, "/foo/bar").should be_ok
          browse_route(verb, "/foo/bar").body.should == "baz" unless verb == :head
        end

        it "ignores #{verb} if auto namespaceing is disabled" do
          app.disable :auto_namespace
          App::Foo.should_not respond_to(verb)
          proc { App::Foo.send(verb, "/bar") { "baz" } }.should raise_error(NameError)
          App::Foo.should_not respond_to(verb)
        end

        it "ignores #{verb} if told to via :except" do
          app.set :auto_namespace, :except => verb
          App::Foo.should_not respond_to(verb)
          proc { App::Foo.send(verb, "/bar") { "baz" } }.should raise_error(NameError)
          App::Foo.should_not respond_to(verb)
        end

        it "does not ignore #{verb} if not included in :except" do
          app.set :auto_namespace, :except => ["prefix"]
          App::Foo.should_not respond_to(verb)
          App::Foo.send(verb, "/bar") { "baz" }
          App::Foo.should respond_to(verb)
        end

        it "does ignore #{verb} if not included in :only" do
          app.set :auto_namespace, :only => "prefix"
          App::Foo.should_not respond_to(verb)
          proc { App::Foo.send(verb, "/bar") { "baz" } }.should raise_error(NameError)
          App::Foo.should_not respond_to(verb)
        end

        it "does not ignore #{verb} if included in :only" do
          app.set :auto_namespace, :only => ["prefix", verb]
          App::Foo.should_not respond_to(verb)
          App::Foo.send(verb, "/bar") { "baz" }
          App::Foo.should respond_to(verb)
        end

        it "detects prefix" do
          App::Foo.should_not respond_to(:prefix)
          App::Foo.prefix.should == "/foo"
        end
      end

      describe :helpers do
        it "makes helpers defined inside a namespace not available to routes outside that namespace" do
          helpers { define_method(:foo) { 42 } }
          app.namespace("/foo").helpers { define_method(:bar) { 42 } }
          app.new.should respond_to(:foo)
          app.new.should_not respond_to(:bar)
        end

        it "allows overwriting helpers for routes within a namespace" do
          helpers { define_method(:foo) { "foo" } }
          define_route(verb, "/foo") { foo }
          app.namespace("/bar") do
            define_method(:foo) { "bar" }
            send(verb, "/foo") { foo }
          end
          browse_route(verb, "/foo").should be_ok
          browse_route(verb, "/bar/foo").should be_ok
          unless verb == :head
            browse_route(verb, "/foo").body.should == "foo"
            browse_route(verb, "/bar/foo").body.should == "bar"
          end
        end

        it "allows accessing helpers defined outside the namespace" do
          helpers { define_method(:foo) { "foo" } }
          app.namespace("/foo").send(verb, "") { foo }
          browse_route(verb, "/foo").should be_ok
          browse_route(verb, "/foo").body.should == "foo" unless verb == :head
        end

        it "allows calling super in helpers overwritten inside a namespace" do
          helpers { define_method(:foo) { "foo" } }
          app.namespace("/foo") do
            define_method(:foo) { super().upcase }
            send(verb) { foo }
          end
          browse_route(verb, "/foo").should be_ok
          browse_route(verb, "/foo").body.should == "FOO" unless verb == :head
        end
      end

    end
  end

  describe :errors do
    it "should allow custom error handlers with not found" do
      app.namespace('/de') do
        not_found { 'nicht gefunden' }
      end
      get('/foo').status.should     == 404
      last_response.body.should_not == 'nicht gefunden'
      get('/en/foo').status.should  == 404
      last_response.body.should_not == 'nicht gefunden'
      get('/de/foo').status.should  == 404
      last_response.body.should     == 'nicht gefunden'
    end

    it "should allow custom error handlers with error" do
      app.namespace('/de') do
        error(404) { 'nicht gefunden' }
      end
      get('/foo').status.should     == 404
      last_response.body.should_not == 'nicht gefunden'
      get('/en/foo').status.should  == 404
      last_response.body.should_not == 'nicht gefunden'
      get('/de/foo').status.should  == 404
      last_response.body.should     == 'nicht gefunden'
    end
  end

  describe 'conditions' do
    it 'allows using conditions' do
      app.namespace(:host_name => 'example.com') do
        get('/') { 'yes' }
      end
      app.get('/') { 'no' }
      get('/', {}, { 'HTTP_HOST' => 'example.com' })
      last_response.body.should == 'yes'
      get('/', {}, { 'HTTP_HOST' => 'example.org' })
      last_response.body.should == 'no'
    end

    it 'allows combining conditions with a prefix' do
      app.namespace('/foo', :host_name => 'example.com') do
        get { 'yes' }
      end
      app.get('/foo') { 'no' }
      get('/foo', {}, { 'HTTP_HOST' => 'example.com' })
      last_response.body.should == 'yes'
      get('/foo', {}, { 'HTTP_HOST' => 'example.org' })
      last_response.body.should == 'no'
    end
  end

  describe 'memory' do
    before do
      app.namespace('/foo') { get('/bar') { 'blah' }}
    end

    def measure
      100.times { get('/foo/bar') }
      GC.start
      # ObjectSpace.each_object.to_a.size
      sum = 0
      ObjectSpace.each_object { sum += 1 }
      sum
    end

    it 'should not leak objects' do
      if Monkey::Engine.mri?
        measure
        2.times do
          first   = measure
          second  = measure
          second.should <= first + 3
        end
      end
    end
  end
end
