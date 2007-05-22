
require 'rubygems'
require 'rake/gempackagetask'
require 'rake/testtask'
require 'rake/rdoctask'

desc "clean up stuff"
task :clean => [:clobber_package, :clobber_rdoc]

Rake::RDocTask.new do |rd|
   rd.main = "README.rdoc"
   rd.rdoc_files.include("lib/**/*.rb")
end

Rake::TestTask.new do |t|
   t.libs << "test"
   t.test_files = FileList['test/test*.rb']
   t.verbose = true
end

spec = Gem::Specification.new do |s| 
  s.name = "flat_filer"
  s.version = "0.0.6"
  s.author = "Andrew Libby"
  s.email = "alibby@tangeis.com"
  s.homepage = "http://www.tangeis.com/"
  s.platform = Gem::Platform::RUBY
  s.summary = "Library for processing flat files"
  s.files = FileList["lib/**/*"].to_a
  s.require_path = "lib"
#  s.autorequire = "name"
  s.test_files = FileList["{test}/**/*test.rb"].to_a
  s.has_rdoc = true
#  s.extra_rdoc_files = ["README"]
#  s.add_dependency("dependency", ">= 0.x.x")
end

Rake::GemPackageTask.new(spec) do |pkg| 
  pkg.need_tar = true 
end 

