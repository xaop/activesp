ACTIVESP_VERSION = File.readlines("VERSION")[0][/[\d.]*/]

Gem::Specification.new do |s|
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
  s.add_dependency('savon', '= 0.9.2')
  s.add_dependency('curb')
  s.add_dependency('httpi', '= 0.9.4')
  # s.rdoc_options << '--exclude' << 'ext' << '--main' << 'README'
  # s.extra_rdoc_files = ["README"]
  s.has_rdoc = false
  s.require_paths << 'lib'
  # s.autorequire = 'mysql'
  s.required_ruby_version = '>= 1.8.1'
  s.platform = Gem::Platform::RUBY
end
