
Gem::Specification.new do |s|
  s.name = 'flat_filer'
  s.version = '0.1.0'
  s.author = 'Andrew Libby'
  s.email = 'alibby@andylibby.org'
  s.homepage = 'https://github.com/alibby/flat_filer'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Library for processing flat files'
  s.files = Dir["lib/**/*"].to_a
  s.require_path = "lib"
  s.has_rdoc = true

  s.add_dependency 'activesupport', '~>5.1'
  s.add_development_dependency 'rspec', '~>3.7'
  s.add_development_dependency 'pry', '~>0.11'
end

