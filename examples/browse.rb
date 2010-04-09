require 'rubygems'
$:.unshift("../lib") # Give priority to the local install
require 'activesp'

def browse(item, indentation = 0)
  puts "  " * indentation + "- " + item.class.to_s + " : " + item.url
  case item
  when ActiveSP::Site
    puts "  " * indentation + "    Title = #{item.Title}, Description = #{item.Description}"
    item.sites.each { |site| browse(site, indentation + 1) }
    item.lists.each { |list| browse(list, indentation + 1) }
  when ActiveSP::List
    puts "  " * indentation + "    Description = #{item.Description}, Hidden = #{item.Hidden}"
    item.items.each { |item| browse(item, indentation + 1) }
  when ActiveSP::Folder
    item.items.each { |item| browse(item, indentation + 1) }
  when ActiveSP::Item
    item.content_urls.each do |url|
      puts "  " * indentation + "    Content URL = #{url}"
    end
  end
end

c = ActiveSP::Connection.new(YAML.load(File.read("config.yml")))

browse(c.root)
