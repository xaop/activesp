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
  
  class User < Base
    
    extend Caching
    extend PersistentCaching
    include Util
    include InSite
    
    # @private
    attr_reader :login_name
    
    persistent { |site, login_name, *a| [site.connection, [:user, login_name]] }
    # @private
    def initialize(site, login_name, attributes_before_type_cast = nil)
      @site, @login_name = site, login_name
      @attributes_before_type_cast = attributes_before_type_cast if attributes_before_type_cast
    end
    
    # See {Base#key}
    # @return [String]
    def key
      encode_key("U", [@login_name])
    end
    
    # See {Base#save}
    # @return [void]
    def save
      p untype_cast_attributes(@site, nil, internal_attribute_types, changed_attributes, false)
    end
    
    # @private
    def to_s
      "#<ActiveSP::User login_name=#{login_name}>"
    end
    
    # @private
    alias inspect to_s
    
  private
    
    def data
      call("UserGroup", "GetUserInfo", "userLoginName" => @login_name).xpath("//spdir:User", NS).first
    end
    cache :data
    
    def attributes_before_type_cast
      clean_attributes(data.attributes)
    end
    cache :attributes_before_type_cast
    
    def original_attributes
      type_cast_attributes(@site, nil, internal_attribute_types, attributes_before_type_cast)
    end
    cache :original_attributes
    
    def internal_attribute_types
      @@internal_attribute_types ||= {
        "Email" => GhostField.new("Email", "Text", false, true),
        "ID" => GhostField.new("ID", "Text", false, true),
        "IsDomainGroup" => GhostField.new("Email", "Bool", false, true, "Is Domain Group?"),
        "IsSiteAdmin" => GhostField.new("IsSiteAdmin", "Bool", false, true, "Is Site Admin?"),
        "LoginName" => GhostField.new("LoginName", "Text", false, true, "Login Name"),
        "Name" => GhostField.new("Name", "Text", false, true),
        "Notes" => GhostField.new("Notes", "Text", false, true),
        "Sid" => GhostField.new("Sid", "Text", false, true)
      }
    end
    
  end
  
end
