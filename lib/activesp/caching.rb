module ActiveSP
  
  module Caching
    
    def cache(name, options = {})
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
            @#{name} = #{name}__uncached(*a, &b)
          end#{".dup" if duplicate}
        end
        #{access} :#{name}
        undef reload if instance_methods.include?("reload")
        def reload
          #{@cached_methods.map { |m| "remove_instance_variable(:@#{m}) if defined?(@#{m})" }.join(';')}
          super if defined? super
        end
      RUBY
    end
    
  end
  
end
