require 'savon'

Savon::Request.logger.level = Logger::ERROR

module ActiveSP
  
  class Connection
    
    include Util
    
    # TODO: create profile
    attr_reader :login, :password
    
    def initialize(options = {})
      @root_url = options.delete(:root) or raise ArgumentError, "missing :root option"
      @login = options.delete(:login)
      @password = options.delete(:password)
      options.empty? or raise ArgumentError, "unknown options #{options.keys.map { |k| k.inspect }.join(", ")}"
    end
    
    def find_by_key(key)
      type, trail = decode_key(key)
      case type[0]
      when ?S
        ActiveSP::Site.new(self, trail[0], trail[1].to_i)
      when ?L
        ActiveSP::List.new(find_by_key(trail[0]), trail[1])
      when ?F
        ActiveSP::Folder.new(find_by_key(trail[0]), trail[1], trail[2])
      when ?I
        ActiveSP::Item.new(find_by_key(trail[0]), trail[1], trail[2])
      else
        raise "not yet #{key.inspect}"
      end
    end
    
  end
  
end
