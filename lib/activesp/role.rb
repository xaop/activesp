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
  
  class Role < Base
    
    extend Caching
    extend PersistentCaching
    include Util
    include InSite
    
    persistent { |site, name, *a| [site.connection, [:role, name]] }
    # @private
    def initialize(site, name)
      @site, @name = site, name
    end
    
    # See {Base#key}
    # @return [String]
    def key
      encode_key("R", [@name])
    end
    
    # Returns the list of users in this role
    # @return [User]
    def users
      call("UserGroup", "GetUserCollectionFromRole", "roleName" => @name).xpath("//spdir:User", NS).map do |row|
        attributes = clean_attributes(row.attributes)
        User.new(@site, attributes["LoginName"])
      end
    end
    cache :users, :dup => :always
    
    # Returns the list of groups in this role
    # @return [Group]
    def groups
      call("UserGroup", "GetGroupCollectionFromRole", "roleName" => @name).xpath("//spdir:Group", NS).map do |row|
        attributes = clean_attributes(row.attributes)
        Group.new(@site, attributes["Name"])
      end
    end
    cache :groups, :dup => :always
    
    # Returns true. The same method is present on {Group} where it returns false. Roles and groups can generally be
    # duck-typed, and this method is there for the rare case where you do need to make the distinction
    # @return [Boolean]
    def is_role?
      true
    end
    
    # See {Base#save}
    # @return [void]
    def save
      p untype_cast_attributes(@site, nil, internal_attribute_types, changed_attributes)
    end
    
    # @private
    def to_s
      "#<ActiveSP::Role name=#{@name}>"
    end
    
    # @private
    alias inspect to_s
    
  private
    
    def data
      call("UserGroup", "GetRoleInfo", "roleName" => @name).xpath("//spdir:Role", NS).first
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
        "Description" => GhostField.new("Description", "Text", false, true),
        "ID" => GhostField.new("ID", "Text", false, true),
        "Name" => GhostField.new("Name", "Text", false, true),
        "Type" => GhostField.new("Type", "Integer", false, true)
      }
    end
    
  end
  
end
