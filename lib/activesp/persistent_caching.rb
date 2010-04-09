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
