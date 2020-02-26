require 'erb'

module ActiveSP
  module Soap
    class GetToken
      SOURCE = "get_sharepoint_token.xml.erb"
      URL = "https://login.microsoftonline.com/rst2.srf"

      attr_accessor :security

      def self.initialize
        return if @initialized == true
        @erb          = ERB.new(::File.read ::File.dirname(__FILE__) + '/' + SOURCE)
        @erb.filename = SOURCE
        @erb.def_method self, 'render()'
        @initialized  = true
      end

      def initialize params = {}
        GetToken.initialize
        @url = GetToken::URL
        @security = params[:security]
      end
    end
  end
end
