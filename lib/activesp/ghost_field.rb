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
  
  # This class represents the field definitions for objects in SharePoint for which the
  # fields cannot be changed and are thus not represented by an object in SharePoint.
  # These include fields of sites, lists, users, grouos, roles, content types and fields.
  # The interface of this class is not as complete as the interface if a Field, mainly
  # because it does not make much sense to do so
  class GhostField
    
    include Util
    
    # @private
    attr_reader :Name, :internal_type, :Mult, :ReadOnly, :DisplayName
    
    # @private
    def initialize(name, type, mult, read_only, display_name = name)
      @Name, @DisplayName, @internal_type, @Mult, @ReadOnly = name, display_name, type, mult, read_only
    end
    
    # @private
    def Type
      translate_internal_type(self)
    end
    
    # Returns the attributes of this object as a Hash
    # @return [Hash{String => Integer, Float, String, Time, Boolean, Base}]
    def attributes
      original_attributes.dup
    end
    
    # Returns the value of the attribute of the given name, or nil if this object does not have an attribute by the given name
    # @param [String] name The name of the attribute
    # @return [Integer, Float, String, Time, Boolean, Base]
    def attribute(name)
      current_attributes[name]
    end
    
    # Returns whether or not this object has an attribute with the given name
    # @param [String] name The name of the attribute
    # @return [Boolean]
    def has_attribute?(name)
      current_attributes.has_key?(name)
    end
    
    # See {Base#method_missing}
    def method_missing(m, *a, &b)
      ms = m.to_s
      if a.length == 0 && has_attribute?(ms)
        attribute(ms)
      else
        super
      end
    end
    
  private
    
    def current_attributes
      original_attributes
    end
    
    def original_attributes
      @original_attributes ||= {
        "ColName" => @Name,
        "DisplayName" => @DisplayName,
        "Mult" => @Mult,
        "Name" => @Name,
        "ReadOnly" => @ReadOnly,
        "StaticName" => @Name,
        "Type" => self.Type
      }
    end
    
  end
  
end
