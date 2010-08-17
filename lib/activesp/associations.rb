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
        elements.each(&blk)
      end
      
      def first
        elements.first
      end
      
      def last
        elements.last
      end
      
      def reload
        @elements = nil
      end
      
    private
      
      def elements
        @elements ||= @element_getter.call
      end
      
    end
    
  private
    
    def association(name, &blk)
      proxy = Class.new(AssociationProxy, &blk)
      old_method = instance_method(name)
      define_method(name) do |*a|
        proxy.new(self) do
          old_method.bind(self).call(*a)
        end
      end
    end
    
  end
  
end
