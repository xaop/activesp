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

  s.add_dependency('savon', '~> 2.14.0')
  s.add_dependency('nokogiri')
  s.add_dependency('curb')

  s.required_ruby_version = '>= 2.7.0'
  s.platform = Gem::Platform::RUBY
end
