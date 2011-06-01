module ActiveSP
  
  class AccessDenied < Exception
  end
  
  class AlreadyExists < Exception
    
    def initialize(msg, &object_blk)
      super(msg)
      @object_blk = object_blk
    end
    
    def object
      @object_blk.call
    end
    
  end
  
end
