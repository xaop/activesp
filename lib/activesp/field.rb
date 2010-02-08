module ActiveSP
  
  class Field
    
    attr_reader :name, :type, :data
    
    def initialize(name, type, data)
      @name, @type, @data = name, type, data
    end
    
    def to_s
      "#<ActiveSP::Field name=#{@name}>"
    end
    
    alias inspect to_s
    
  end
  
end
