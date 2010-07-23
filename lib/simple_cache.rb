module SimpleCache

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods

    # In addition to adding the aliased methods this also creates them
    def alias_simple_cache_method_chain(target,refresh_interval,*precache_methods)
      # Shamelessly copied from alias_method_chain
      # Strip out punctuation on predicates or bang methods since
      # e.g. target?_without_feature is not a valid method name.
      aliased_target, punctuation = target.to_s.sub(/([?!=])$/, ''), $1
      yield(aliased_target, punctuation) if block_given?

      with_method, without_method = "#{aliased_target}_with_simple_cache_#{punctuation}", "#{aliased_target}_without_simple_cache_#{punctuation}"

      class_eval(<<-EVAL, __FILE__, __LINE__)     
        def #{with_method}(*args)
          #{precache_methods.join('\n')}
          simple_cache(:#{without_method},#{refresh_interval},*args)
        end
      EVAL

      alias_method without_method, target
      alias_method target, with_method

      case
      when public_method_defined?(without_method)
        public target
      when protected_method_defined?(without_method)
        protected target
      when private_method_defined?(without_method)
        private target
      end

    end

    def simple_cache(method,refresh_interval,*args)
      simple_cache_base(self,method,refresh_interval,args)
    end
    def simple_cache_purge(method, *args)
      simple_cache_purge_base(self,method,args)
    end

    # Base functions used by both Instance and Class methods
    def simple_cache_purge_base(obj,method,args)
      result = Rails.cache.write(simple_cache_key(obj,method,args),[nil,nil])
      raise "Cache Write Failure" unless result
    end
    def simple_cache_base(obj,method,refresh_interval,args)
      ck = simple_cache_key(obj,method,args)
      value,timestamp = simple_cache_read(ck)
      if simple_cache_stale?(timestamp)
        value = obj.send(method,*args)
        simple_cache_write!(ck,value,refresh_interval)
      end
      value
    end

    protected
    def simple_cache_key(obj,method,args)
      "scache:#{simple_cache_object_key_name(obj)}:#{method.to_s}:#{simple_cache_key_args(args)}"
    end
    def simple_cache_key_args(args)
      args.map { |arg|
        simple_cache_object_key_name(arg)
      }.join(",")
    end
    def simple_cache_object_key_name(obj)
      if obj.is_a? ActiveRecord::Base
        "#{obj.class.name}:#{obj.id}"
      else
        obj.to_s.gsub(" ","*")
      end
    end
    def simple_cache_stale?(timestamp)
      !timestamp || (timestamp < Time.now)
    end
    def simple_cache_read(cache_key)
      Rails.cache.read(cache_key)
    end
    def simple_cache_write!(cache_key,value,refresh_interval)
      result = Rails.cache.write(cache_key, [value,Time.now+refresh_interval])
      raise "Cache Write Failure" unless result # Maybe fail gracefully here instead
    end
  end

  # Instance Methods
  def simple_cache(method,refresh_interval,*args)
    self.class.simple_cache_base(self,method,refresh_interval,args)
  end
  def simple_cache_purge(method,*args)
    self.class.simple_cache_purge_base(self,method,args)
  end

end

