require 'rubygems'
require 'activesp'
require 'pp'

c = ActiveSP::Connection.new(YAML.load(File.read("config.yml")))

item = c.root / "wp" / "searchsummary.dwp"
p item
pp item.attributes
p item.attributes["Title"]
p item.attribute("Title")
p item.Title
