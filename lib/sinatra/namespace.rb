require 'sinatra/base'

module Sinatra
  module Namespace
    module NestedMethods
      attr_reader :prefix, :options, :base

      def get(name = nil, options = {}, &block)     prefixed(:get,    name, options, &block) end
      def put(name = nil, options = {}, &block)     prefixed(:put,    name, options, &block) end
      def post(name = nil, options = {}, &block)    prefixed(:post,   name, options, &block) end
      def delete(name = nil, options = {}, &block)  prefixed(:delete, name, options, &block) end
      def head(name = nil, options = {}, &block)    prefixed(:head,   name, options, &block) end
      def before(name = nil, &block)                prefixed(:before, name,          &block) end
      def after(name = nil, &block)                 prefixed(:after,  name,          &block) end

      def helpers(*list, &block)
        include(*list) unless list.empty?
        class_eval(&block) if block
      end

      private

      def app
        return base if base.is_a? Class
        base.app
      end

      def prefixed_path(name)
        if prefix.is_a? Regexp or name.is_a? Regexp
          path = /#{prefix}#{name}/
          path = /^#{path}$/ if base.is_a? Class
        else
          path = prefix.to_s + name.to_s
        end
      end

      def prefixed(method, name, *args, &block)
        if name.respond_to? :key?
          args.unshift name
          name = nil
        end
        options.each { |o, a| app.send(o, *a ) }
        base.send(method, prefixed_path(name), *args, &block)
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
    end

    module ModularMethods
      def setup(base, prefix = nil, options = {}, mixin = nil, &block)
        prefix, options = nil, prefix if options.empty? and prefix.respond_to? :key?
        prefix ||= "/*"
        mixin  ||= self
        mixin.class_eval { @prefix, @options, @base = prefix, options, base }
        mixin.extend ClassMethods, NestedMethods
        mixin.before { extend mixin }
        mixin.class_eval(&block) if block
        mixin
      end
    end

    extend ModularMethods

    def self.make_namespace(mod, options = {})
      from = caller[0] =~ /make_namespace/ ? caller[1] : caller[0]
      #warn "#{from}: Sinatra::Namespace.make_namespace is deperacted, use Sinatra::Namespace.setup instead."
      options[:prefix] ||= mod.name.gsub(/::/, '/').gsub(/([a-z\d]+)([A-Z][a-z])/,'\1_\2').downcase
      setup options.delete(:base) || options.delete(:for), options.delete(:prefix), options, mod
    end

    def self.included(klass)
      klass.extend ModularMethods
      super
    end

    def self.registered(klass)
      klass.extend ClassMethods
    end
  end

  register Namespace
end
