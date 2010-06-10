require "monkey"
require "sinatra/base"
require "sinatra/sugar"
require "sinatra/advanced_routes"

module Sinatra
  module Namespace
    DONT_FORWARD = %w[call configure disable enable new register reset! run! set use template]

    module NestedMethods
      def errors
        @errors ||= {}
      end

      def prefix(value = nil)
        @prefix = value if value
        @prefix
      end

      def base(value = nil)
        @base = value if value
        @base
      end

      def helpers(*modules, &block)
        modules.each { |m| include m }
        class_eval(&block) if block
      end

      def get(name = nil, options = {}, &block);    prefixed(:get,    name, options, &block); end
      def put(name = nil, options = {}, &block);    prefixed(:put,    name, options, &block); end
      def post(name = nil, options = {}, &block);   prefixed(:post,   name, options, &block); end
      def delete(name = nil, options = {}, &block); prefixed(:delete, name, options, &block); end
      def head(name = nil, options = {}, &block);   prefixed(:head,   name, options, &block); end

      def error(codes=Exception, &block)
        [*codes].each { |c| errors[c] = block }
      end

      def not_found(&block)
        error(404, &block)
      end

      def respond_to?(name)
        super or (base.respond_to? name and forward? name)
      end

      def methods(*args)
        (super + base.methods(*args).select { |m| forward? m }).uniq
      end

      def before_filters
        @before_filters ||= []
      end

      def after_filters
        @after_filters ||= []
      end

      def before(&block)
        before_filters << block
      end

      def after(&block)
        after_filters << block
      end

      private

      def always_activate
        get(/.*/) { pass }
      end

      def application
        klass = self
        klass = klass.base while klass.respond_to? :base
        klass
      end

      def prefixed(verb, name = nil, options = {}, &block)
        name, options = nil, name if name.is_a? Hash and options.empty?
        if prefix.is_a? Regexp or name.is_a? Regexp
          path = /#{prefix}#{name}/
          path = /^#{path}$/ if base.is_a? Class
        else
          path = prefix.to_s + name.to_s
        end
        application.send(:define_method, "#{verb} #{path}", &block)
        unbound_method, container = application.instance_method("#{verb} #{path}"), self
        if block.arity != 0 
          wrapper = proc { |*args| container.send(:wrap, unbound_method, self, *args) }
        else
          wrapper = proc { container.send(:wrap, unbound_method, self) }
        end
        base.send(verb, path, options, &wrapper)
      end

      def prepare_instance(app)
        return if app.is_a? self
        base.prepare_instance app if base.respond_to? :prepare_instance
        class << app
          @filters ||= {}
          @filters[:after] ||= []
          @after_filters ||= []
        end
        before_filters.each { |block| app.instance_eval(&block) }
        after_filters.each { |block| app.singleton_class.after(&block) }
        app.extend self
      end

      def wrap(unbound_method, app, *args)
        prepare_instance app
        app.current_namespace = self
        unbound_method.bind(app).call(*args)
      end

      def method_missing(name, *args, &block)
        Monkey.invisible { super }
      rescue NameError => error # allowes adding method_missing in mixins
        raise error unless base.respond_to? name and forward? name
        base.send(name, *args, &block)
      end

      def forward?(name)
        not Sinatra::Namespace::DONT_FORWARD.include? name.to_s
      end
    end

    def self.registered(klass)
      klass.register Sinatra::Sugar
      klass.__send__ :include, InstanceMethods
      klass.enable :merge_namespaces, :auto_namespace, :always_activate_namespaces
    end

    def self.make_namespace(mod, options = {})
      unless options[:base] ||= options[:for]
        base = mod
        base = base.parent until base.is_a? Class
        raise ArgumentError, "base class not given/detected" if base == Object
        options[:base] = base
      end
      options[:prefix] ||= "/" << mod.name.gsub(/^#{options[:base]}::/, '').to_const_path
      mod.extend self
      mod.extend NestedMethods
      options.each { |k,v| mod.send(k, v) }
      mod.send(:always_activate) if options[:base].always_activate_namespaces?
      mod
    end

    module InstanceMethods
      attr_accessor :current_namespace

      if Sinatra::Base > '1.0' or Sinatra::Base.respond_to? :filters # master is still 1.0
        def filter!(type, base = self.class)
          super
          if type == :after and base == self.class and singleton_class.after_filters
            singleton_class.after_filters.each { |b| instance_eval(&b) }
          end
        end
      else
        def after_filter!(base = self.class)
          super
          if base == self.class and singleton_class.after_filters
            singleton_class.after_filters.each { |b| instance_eval(&b) }
          end
        end
      end

      def error_block!(*keys)
        keys.detect do |key|
          base = current_namespace || self.class
          while base.respond_to? :errors
            if block = base.errors[key]
              # found a handler, eval and return result
              return instance_eval(&block)
            else
              base = base.respond_to?(:base) ? base.base : base.superclass
            end
          end
        end
      end
    end

    def make_namespace(mod, options = {})
      Sinatra::Namespace.make_namespace mod, options.merge(:base => self)
    end

    def namespace(prefix, merge = nil, &block)
      if merge or (merge.nil? and merge_namespaces?)
        @namespaces ||= {}
        @namespaces[prefix] ||= namespace prefix, false
        @namespaces[prefix].class_eval(&block) if block
        @namespaces[prefix]
      else
        mod = make_namespace Module.new, :prefix => prefix
        mod.class_eval(&block) if block
        mod
      end
    end

    def nested_method_missing(klass, meth, *args, &block)
      return super unless make_namespace? klass, meth
      make_namespace klass
      klass.send(meth, *args, &block)
    end

    def make_namespace?(klass, meth)
      return false if !auto_namespace? or klass.is_a? NestedMethods
      meths = NestedMethods.instance_methods.map { |m| m.to_s }
      if auto_namespace != true
        meths = [auto_namespace[:only]].flatten.map { |m| m.to_s } if auto_namespace.include? :only
        [auto_namespace[:except]].flatten.each { |m| meths.delete m.to_s } if auto_namespace.include? :except
      end
      meths.include? meth.to_s
    end
  end

  register Namespace
end