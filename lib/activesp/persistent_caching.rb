module ActiveSP
  
  module PersistentCaching
    
    def persistent(&blk)
      class << self ; self ; end.instance_eval do
        alias_method :old_new, :new
        define_method(:new) do |*a|
          cache_scope, indices = *blk.call(a)
          if cache_scope.respond_to?(:persistent_cache)
            cache_scope.persistent_cache.lookup(indices) { old_new(*a) }
          else
            old_new(*a)
          end
        end
      end
    end
    
  end
  
  class PersistentCache
    
    def initialize
      @cache = {}
    end
    
    def lookup(indices)
      if o = @cache[indices]
        # puts "  Cache hit for #{indices.inspect}"
      else
        o = @cache[indices] ||= yield
        # puts "  Cache miss for #{indices.inspect}"
      end
      o
    end
    
  end
  
  module PersistentCachingConfig
    
    def configure_persistent_cache(&blk)
      @last_persistent_cache_object = PersistentCache.new
      class << self ; self ; end.send(:define_method, :persistent_cache) do
        cache = blk.call(@last_persistent_cache_object)
        @last_persistent_cache_object = PersistentCache.new unless cache == @last_persistent_cache_object
        cache
      end
    end
    
  end
  
end
