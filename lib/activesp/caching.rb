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
  module Caching
    
  private
    
    def cache(name, options = {})
      options = options.dup
      duplicate = options.delete(:dup)
      options.empty? or raise ArgumentError, "unsupported options #{options.keys.map { |k| k.inspect }.join(", ")}"
      (@cached_methods ||= []) << name
      alias_method("#{name}__uncached", name)
      access = private_instance_methods.include?(name) ? "private" : protected_instance_methods.include?(name) ? "protected" : "public"
      private("#{name}__uncached")
      module_eval <<-RUBY
        def #{name}(*a, &b)
          if defined? @#{name}
            @#{name}
          else
            @#{name} = #{name}__uncached(*a, &b)#{".dup" if duplicate == :once}
          end#{".dup" if duplicate == :always}
        end
        #{access} :#{name}
        remove_method(:reload) if instance_methods(false).include?("reload")
        def reload
          #{@cached_methods.map { |m| "remove_instance_variable(:@#{m}) if defined?(@#{m})" }.join(';')}
          super if defined? super
        end
      RUBY
    end
    
  end
  
end
