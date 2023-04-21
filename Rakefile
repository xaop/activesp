# Copyright (c) 2010 XAOP bvba
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

require 'rubygems'
require 'rake/gempackagetask'
require 'yard'

ACTIVESP_VERSION = File.readlines("VERSION")[0][/[\d.]*/]

desc "Build the gem"
spec = Gem::Specification.new do |s|
  s.name = "activesp"
  s.version = ACTIVESP_VERSION
  s.author = "Peter Vanbroekhoven"
  s.email = "peter@xaop.com"
  s.homepage = "http://www.xaop.com/labs/activesp"
  s.summary = "Interface to SharePoint"
  s.description = "An object-oriented interface to SharePoint that uses the web services provided by SharePoint to connect to it. Supports SharePoint 2007 and 2010."
  s.files += %w(VERSION LICENSE README.rdoc Rakefile)
  s.files += Dir['lib/**/*.rb']
  # s.bindir = "bin"
  # s.executables.push(*(Dir['bin/*.rb']))
  s.add_dependency('savon-xaop')
  s.add_dependency('nokogiri')
  s.add_dependency('curb')
  # s.rdoc_options << '--exclude' << 'ext' << '--main' << 'README'
  # s.extra_rdoc_files = ["README"]
  s.has_rdoc = false
  s.require_paths << 'lib'
  # s.autorequire = 'mysql'
  s.required_ruby_version = '>= 1.8.1'
  s.platform = Gem::Platform::RUBY
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

YARD::Rake::YardocTask.new do |t|
  t.options = ['--no-private', '--readme', 'README.rdoc']
end
