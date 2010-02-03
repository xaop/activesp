module ActiveSP
  
  module Caching
    
    def self.included(cl)
      cl.extend(ClassMethods)
    end
    
    module ClassMethods
      
      def cache(name)
        (@cached_methods ||= []) << name
        alias_method("#{name}__uncached", name)
        module_eval <<-RUBY
          def #{name}(*a, &b)
            if defined? @#{name}
              @#{name}
            else
              @#{name} = #{name}__uncached(*a, &b)
            end
          end
          def reload
            #{@cached_methods.map { |m| "remove_instance_variable(:@#{m}) if defined?(@#{m})" }.join(';')}
            super if defined? super
          end
        RUBY
      end
      
    end
    
  end
  
end
