require 'rubygems'
$:.unshift("../lib") # Give priority to the local install
require 'activesp'

c = ActiveSP::Connection.new(YAML.load(File.read("config.yml")))

wp = c.root / "wp"

p wp

pp wp.fields
pp wp.content_types
t = wp.content_types.first
p t
pp t.fields
