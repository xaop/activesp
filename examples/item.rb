require 'rubygems'
$:.unshift("../lib") # Give priority to the local install
require 'activesp'
require 'pp'

c = ActiveSP::Connection.new(YAML.load(File.read("config.yml")))

item = c.root / "Shared Documents" / "documentum.pdf"
p item
pp item.attributes
p item.attributes["Title"]
p item.attribute("Title")
p item.Title
