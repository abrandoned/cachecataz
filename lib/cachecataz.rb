module Cachecataz
  # Default config for Rails.cache, disabled, and [":", "/"] delims
  #
  # @example configure in an environment file (development.rb, production.rb) for Rails
  #
  #   config.after_initialize do
  #     Cachecataz.enable = true
  #     Cachecataz.provider = Rails.cache
  #     Cachecataz.random = false  # default "random" is true, and true is recommended
  #   end
  Config = {
      :api => {
        :get => :read, 
        :set => :write, 
        :exist? => :exist?
      }, 
    :enabled => false,
    :namespace_delimiter => ":",
    :index_delimiter => "/", 
    :random => true 
  }

  # Config method to enable Cachecataz
  #
  # @param [Boolean] val
  def self.enable=(val)
    ::Cachecataz::Config[:enabled] = val
  end

  # Config method to randomize the seed for namespaces in Cachecataz.  (default to true, the recommended setting)
  #
  # @param [Boolean] val
  def self.random=(val)
    ::Cachecataz::Config[:random] = val
  end

  # Set custom delimiter if desired
  def self.delimiter=(val)
    ::Cachecataz::Config[:namespace_delimiter] = val.first rescue ":"
    ::Cachecataz::Config[:index_delimiter] = val.last rescue "/"
  end

  # Config method to assign the provider, for Rails this is Rails.cache
  #
  # @param [Object] val an object that responds to the api provided
  def self.provider=(val)
    ::Cachecataz::Config[:provider] = val
  end

  # Config method that maps the api method calls from the provider to the caching server
  # example is the mapping for the Rails.cache provider
  #
  # @example Cachecataz.api = {:get => :read, :set => :write, :incr => :increment, :exist? => :exist?}
  # 
  # @param [Hash] api a hash of symbols or procs/lambdas mapped to each of [:get, :set, :incr, :exist?]
  def self.api=(api)
    validate_api(api)
    ::Cachecataz::Config[:api] = api
  end  

  # [] operator to run the actual calls on the cache provider configured
  def self.[](*api_args)
    return false unless ::Cachecataz::Config[:enabled]

    api_method = api_args.slice!(0)

    case
    when ::Cachecataz::Config[:api][api_method].respond_to?(:call) then
      ::Cachecataz::Config[:api][api_method].call(*api_args)
    when ::Cachecataz::Config[:provider].respond_to?(::Cachecataz::Config[:api][api_method]) then
      ::Cachecataz::Config[:provider].__send__(::Cachecataz::Config[:api][api_method], *api_args)
    else
      raise "Unknown method: #{api_method} for provider: #{::Cachecataz::Config[:provider]}"
    end
  end

  # Method that validates the api and provider if they are defined in configuration
  def self.validate_api(api={})
    unless api.include?(:get) && api.include?(:set) && api.include?(:exist?)
      raise "Unknown api methods, define [:get, :set, :exist?] to use cachecataz with a non-standard provider"
    end
  end

  # Method that includes and extends the appropriate modules
  def self.included(klass)
    klass.instance_variable_set(:@_point_keys, {})
    klass.__send__(:include, ::Cachecataz::InstanceMethods)
    klass.__send__(:extend, ::Cachecataz::ClassMethods)
  end

  module ClassMethods    
    # Takes the cache_point and the value from the cache
    #
    # @param [Symbol] point_key the symbol that identifies the namespace point
    # @param [Hash] scope_hash the hash that provides the data for creating the namespace key
    # @return [String] cachecataz namespaced cache key
    def cache_key(point_key, scope_hash)
      c_point = cache_point(point_key, scope_hash)
      c_key = ::Cachecataz[:get, c_point].to_s.strip
      return "#{c_key}#{::Cachecataz::Config[:namespace_delimiter]}" << c_point 
    end

    # Determines and returns the cache_point
    # putting i.to_s first in the scope_hash lookup because primarily using with self.attributes in rails which is string keyed
    def cache_point(point_key, scope_hash)
      c_scope = @_point_keys[point_key]   
      c_point = c_scope.inject(point_key.to_s) do |s, i| 
        s << ::Cachecataz::Config[:namespace_delimiter] << (scope_hash[i.to_s] || scope_hash[i]).to_s 
      end

      ::Cachecataz[:set, c_point, ::Cachecataz::Config[:random] ? rand(10000).to_s : "0"] unless ::Cachecataz[:exist?, c_point]
      return c_point
    end

    # Method used in the Class to defined a cachecataz namespace
    # assigns the scope to a class instance variable with the point_key as key
    #
    # @param [Symbol] point_key the name of the cachecataz namespace
    # @param [Array] c_scope the symbols that defined the scope of the namespace
    def cache_scope(point_key, *c_scope)
      c_scope.flatten!
      c_scope.uniq!
      c_scope.sort!{ |a, b| a.to_s <=> b.to_s }
      @_point_keys[point_key] = c_scope
    end

    # Class level method that expires the namespace in the cache for the point_key and 
    # scope data provided
    #
    # @param [Symbol] point_key 
    # @param [Hash] scope_hash the data provider for the scope of the namespace
    def expire_namespace(point_key, scope_hash={})
      c_point = cache_point(point_key, scope_hash)
      ::Cachecataz[:set, c_point, (::Cachecataz[:get, c_point].to_i + 1 rescue rand(10000)).to_s]
    end

    # Class level method to expire all the namespace of cachecataz for a given data provider
    #
    # @param [Hash] scope_hash the data provider for the scope of the namespace
    def expire_all_namespaces(scope_hash={})
      @_point_keys.keys.each{ |k| expire_namespace(k, scope_hash) }
    end

    # Resets a cache namespace to 0, should be needed, but wanted to have something here to do it
    def cachecataz_namespace_reset(point_key, scope_hash={})
      c_point = cache_point(point_key, scope_hash)
      ::Cachecataz[:set, c_point, "0"]
    end

    # provides access for the point_keys stored in the Class instance variable
    def point_key(point_key)
      @_point_keys[point_key]
    end

    # provides access to all point_keys for the Class
    def point_keys
      @_point_keys
    end    
  end

  module InstanceMethods
    # Instance method for accessing the cachecataz namespace identifier
    #
    # @param [Symbol] point_key name of the cache_space defined on the Class
    # @param [Hash] scope_hash provides the data for the namespace key
    # @return [string] namespace key for the cachecataz namespace
    def cachecataz_key(point_key, scope_hash={})
      return "cachecataz disabled" unless ::Cachecataz::Config[:enabled]

      scope_hash = self.attributes if scope_hash == {} && self.respond_to?(:attributes)
      return self.class.cache_key(point_key, scope_hash)
    end

    # Instance method to return a cache_key for the class
    #
    # @note method removes any index that is already in the namespace definition as it can't be 2x as unique on the same key
    #
    # @example user.cache_key(:ck_name, [:id]) # => "0:ck_name/:id"   
    #
    # @param [Symbol] point_key name of the cache_space defined on the Class
    # @param [Array, []] indexes additional data elements that makeup the key for the instance
    # @param [Hash, self.attributes] scope_hash provides the data for the namespace key
    def cache_key(point_key, indexes=[], scope_hash={})
      cache_key_point = cachecataz_key(point_key, scope_hash)
      indexes = [indexes].flatten.compact.uniq

      indexes.reject!{ |i| self.class.point_key(point_key).include?(i) }
      return indexes.inject(cache_key_point) do |s, n| 
        s << ::Cachecataz::Config[:index_delimiter] << self.cachecataz_index_convert(n) 
      end
    end

    # Determines the intended index conversion for index passed to cache_key 
    #
    # @note if index responds to :call then it will check the arity to determine if it is 1, if so it passes self as the argument
    #
    # @param [Object] val the value passed to cache_key index
    # @return [String] string to append to namespace key
    def cachecataz_index_convert(val)
      case
      when val.respond_to?(:call) then
        val.arity == 1 ? val.call(self).to_s : val.call.to_s  
      when val.kind_of?(Symbol) && self.respond_to?(val) then
        self.__send__(val).to_s
      else
        val.to_s
      end
    end

    # Instance method to expire a cachecataz namespace
    #
    # @param [Symbol] point_key name of the cache_space defined on the Class
    # @param [Hash, self.attributes] scope_hash provides the data for the namespace key
    def expire_namespace(point_key, scope_hash={})
      scope_hash = self.attributes if scope_hash == {} && self.respond_to?(:attributes)
      self.class.expire_namespace(point_key, scope_hash)
    end

    # Instance method to expire all namespaces for an object
    def expire_all_namespaces(scope_hash={})
      scope_hash = self.attributes if scope_hash == {} && self.respond_to?(:attributes)
      self.class.expire_all_namespaces(scope_hash)
    end

    # Instance method to reset a namespace, shouldn't really be needed, but avail
    def cachecataz_namespace_reset(point_key, scope_hash={})
      scope_hash = self.attributes if scope_hash == {} && self.respond_to?(:attributes)
      self.class.cachecataz_namespace_reset(point_key, scope_hash)
    end    
  end
end
