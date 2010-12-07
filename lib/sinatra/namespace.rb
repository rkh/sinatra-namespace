require 'sinatra/base'

module Sinatra
  module Namespace
    module NestedMethods
      DONT_FORWARD = %w[call configure disable enable new register reset! run! set use template layout]
      attr_reader :prefix, :options, :base

      def get(name = nil, options = {}, &block)     prefixed(:get,    name, options, &block) end
      def put(name = nil, options = {}, &block)     prefixed(:put,    name, options, &block) end
      def post(name = nil, options = {}, &block)    prefixed(:post,   name, options, &block) end
      def delete(name = nil, options = {}, &block)  prefixed(:delete, name, options, &block) end
      def head(name = nil, options = {}, &block)    prefixed(:head,   name, options, &block) end
      def before(name = "*", &block)                prefixed(:before, name,          &block) end
      def after(name = "*", &block)                 prefixed(:after,  name,          &block) end

      def helpers(*list, &block)
        include(*list) unless list.empty?
        class_eval(&block) if block
      end

      def settings
        return base if base.is_a? Class
        base.settings
      end

      def respond_to?(*args)
        return true if super
        base.respond_to?(*args) and forward(args.first)
      end

      def errors
        @errors ||= {}
      end

      def not_found(&block)
        error(404, &block)
      end

      def error(codes = Exception, &block)
        [*codes].each { |c| errors[c] = block }
      end

      private

      def prefixed_path(name)
        if prefix.is_a? Regexp or name.is_a? Regexp
          path = /#{prefix}#{name}/
          path = /^#{path}$/ if base.is_a? Class
          path
        else
          prefix.to_s + name.to_s
        end
      end

      def prefixed(method, name, *args, &block)
        if name.respond_to? :key?
          args.unshift name
          name = nil
        end
        options.each { |o, a| settings.send(o, *a ) }
        base.send(method, prefixed_path(name), *args, &block)
      end

      def forward?(name)
        not DONT_FORWARD.include? name.to_s
      end

      def method_missing(name, *args, &block)
        return super unless base.respond_to? name and forward? name
        base.send(name, *args, &block)
      end
    end

    module ClassMethods
      def namespace(prefix = nil, options = {}, &block)
        Namespace.setup(self, prefix, options, Module.new, &block)
      end

      def make_namespace(mod, options = {})
        options[:base] ||= self
        Namespace.make_namespace(mod, options)
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

    module ModularMethods
      def setup(base, prefix = nil, options = {}, mixin = nil, &block)
        prefix, options = nil, prefix if options.empty? and prefix.respond_to? :key?
        prefix ||= ""
        mixin  ||= self
        mixin.class_eval { @prefix, @options, @base = prefix, options, base }
        mixin.extend ClassMethods, NestedMethods
        mixin.send(:define_method, :error_block!) do |*keys|
          if block = keys.inject(nil) { |b,k| b ||= mixin.errors[k] }
            instance_eval(&block)
          else
            super(*keys)
          end
        end
        mixin.before { extend mixin }
        mixin.class_eval(&block) if block
        mixin
      end
    end

    module NamespaceDetector
      Module.send(:include, self)
      def method_missing(meth, *args, &block)
        return super if is_a? Class or !name
        base = Object
        detected = name.split('::').any? do |name|
          base = base.const_get(name)
          base < Sinatra::Base
        end
        if detected and base.make_namespace?(self, meth)
          Sinatra::Namespace.make_namespace self, :base => base
          send(meth, *args, &block)
        else
          super
        end
      end
    end

    extend ModularMethods

    def self.make_namespace(mod, options = {})
      base = options.delete(:base) || options.delete(:for)
      options[:prefix] ||= '/' << mod.name.gsub(/^#{base.name}::/, '').
        gsub(/::/, '/').gsub(/([a-z\d]+)([A-Z][a-z])/,'\1_\2').downcase
      setup base, options.delete(:prefix), options, mod
    end

    def self.included(klass)
      klass.extend ModularMethods
      super
    end

    def self.registered(klass)
      klass.extend ClassMethods
      klass.enable :auto_namespace
    end
  end

  Delegator.delegate :namespace
  register Namespace
end
