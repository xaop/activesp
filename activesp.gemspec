ACTIVESP_VERSION = File.readlines("VERSION")[0][/[\d.]*/]

Gem::Specification.new do |s|
  s.name = "activesp"
  s.version = ACTIVESP_VERSION
  s.author = "Peter Vanbroekhoven"
  s.email = "peter@xaop.com"
  s.homepage = "https://github.com/xaop/activesp"
  s.summary = "Interface to SharePoint"
  s.description = "An object-oriented interface to SharePoint that uses the web services provided by SharePoint to connect to it. Supports SharePoint 2007 and 2010."
  s.files += %w(VERSION LICENSE README.rdoc Rakefile)
  s.files += Dir['lib/**/*.rb']
  # s.bindir = "bin"
  # s.executables.push(*(Dir['bin/*.rb']))
  s.add_dependency('savon', '~> 0.9.9')
  s.add_dependency('nokogiri')
  s.add_dependency('curb')
  # s.rdoc_options << '--exclude' << 'ext' << '--main' << 'README'
  # s.extra_rdoc_files = ["README"]
  s.require_paths << 'lib'
  # s.autorequire = 'mysql'
  s.required_ruby_version = '>= 1.8.1'
  s.platform = Gem::Platform::RUBY
end
