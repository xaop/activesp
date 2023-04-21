# Copyright (c) 2010 XAOP bvba
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

module ActiveSP
  # @private
  module PersistentCaching
  private

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

  # @private
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
    # Configures the scope of the persistent cache. The default scope of the cache
    # is the {Connection} object, i.e., each connection has its own cache. For example
    # you can use this to make thread local caches. Note that the cache is not actually
    # thread safe at this point so this may not be such a bad idea.
    #
    # Caching in ActiveSP at the moment is very aggressive. What this means that everything
    # you ever accessed will be cached. You can override the cache for a particular object
    # by calling {Base#reload} on it. One advantage of this caching strategy is that every time
    # you access an object in SharePoint, it is guaranteed to be the same object in Ruby as
    # well, irrespective of how you obtained a reference to that object. This eliminates a
    # whole slew of issues, but you need to be aware of this.
    #
    # This method expects a block to which a new cache object is passed. The idea is that
    # you store this cache object in a place that reflects the scope of your cache. If you
    # already had a cache object stored for you current scope, you do not do anything with
    # the cache object. The cache object that the block returns is the cache that will be used.
    # Note that the block is called everytime ActiveSP needs the cache, so make it as
    # efficient as possible. The example below illustrates how you can use the ||= operator
    # for this to get a thread local cache.
    #
    # You can use this block to return a cache of your own. A cache is only expected to have
    # a lookup method to which the cache key is passed (do not assume it is an integer or a
    # string because it is not) as parameter and is expected to return the value for that
    # key. In case of a cache miss, the method should yield to retrieve the value, store it
    # with the given key and return the value. You can use this to plug in a cache that has
    # a limited size, or that uses weak references to clean up the cache. The latter suggestion
    # is a lot safer than the former!
    #
    # @example How to configure caching strategy
    #   c = ActiveSP::Connection.new(:login => l, :password => p, :root => r)
    #   c.configure_persistent_cache { |cache| Thread.current[:sp_cache] ||= cache }
    def configure_persistent_cache(&blk)
      @last_persistent_cache_object = PersistentCache.new
      class << self ; self ; end.send(:define_method, :persistent_cache) do
        cache = blk.call(@last_persistent_cache_object)
        @last_persistent_cache_object = PersistentCache.new if cache == @last_persistent_cache_object
        cache
      end
    end
  end
end
