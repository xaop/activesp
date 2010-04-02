require 'rubygems'
$:.unshift("../lib") # Give priority to the local install
require 'activesp'

def browse(item, indentation = 0)
  puts "  " * indentation + item.class.to_s + " : " + item.url
  case item
  when ActiveSP::Site
    item.sites.each { |site| browse(site, indentation + 1) }
    item.lists.each { |list| browse(list, indentation + 1) }
  when ActiveSP::List
    item.items.each { |item| browse(item, indentation + 1) }
  when ActiveSP::Folder
    item.items.each { |item| browse(item, indentation + 1) }
  else
  end
end

c = ActiveSP::Connection.new(YAML.load(File.read("config.yml")))

begin
  browse(c.root)
rescue Exception => e
  puts e.message
  p e.class
  puts e.backtrace
end
