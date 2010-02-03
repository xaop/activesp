require 'rubygems'
require 'rake/gempackagetask'

ACTIVESP_VERSION = File.readlines("VERSION")[0][/[\d.]*/]

desc "Build the gem"
spec = Gem::Specification.new do |s|
  s.name = "activesp"
  s.version = ACTIVESP_VERSION
  s.author = "Peter Vanbroekhoven"
  s.email = "peter@xaop.com"
  #s.homepage = "http://www.xaop.com/pages/dctmruby"
  s.summary = "Interface to SharePoint"
  s.description = s.summary
  #s.rubyforge_project = s.name
  s.files += %w(VERSION Rakefile)
  s.files += Dir['lib/**/*.rb']
  # s.bindir = "bin"
  # s.executables.push(*(Dir['bin/*.rb'] - ["bin/encrypt-dmcl.rb"]).map { |f| File.basename(f) })
  s.add_dependency('savon')
  s.add_dependency('nokogiri')
  # s.rdoc_options << '--exclude' << 'ext' << '--main' << 'README'
  # s.extra_rdoc_files = ["README", "docs/README.html"]
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
