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
  module Associations
    
    class AssociationProxy
      
      include Enumerable
      
      def initialize(object, &element_getter)
        @object = object
        @element_getter = element_getter
      end
      
      def each(&blk)
        @element_getter.call(blk)
      end
      
      def first
        each { |element| return element }
        nil
      end
      
      def last
        inject { |_, element| element }
      end
      
      def count
        inject(0) { |cnt, _| cnt + 1 }
      end
      
    end
    
  private
    
    def association(name, each_method = ("each_" + name.to_s.sub(/s\z/, "")).to_sym, &blk)
      proxy = Class.new(AssociationProxy, &blk)
      define_method(name) do |*a|
        proxy.new(self) do |blk|
          send(each_method, *a, &blk)
        end
      end
    end
    
  end
  
end
