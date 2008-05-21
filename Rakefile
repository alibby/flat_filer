
require 'rubygems'
require 'spec'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'kinetic_rakes'
require 'find'

desc "clean up stuff"
task :clean => [:clobber_package, :clobber_rdoc]

Rake::RDocTask.new do |rd|
   rd.main = "README.rdoc"
   rd.rdoc_files.include("lib/**/*.rb")
end

desc "Run specs"
task :spec do 
    Find.find('spec') do |f|
        next unless f.match /.*\.rb$/
        system("spec #{f}")
    end
end

spec = Gem::Specification.new do |s| 
  s.name = "flat_filer"
  s.version = "0.0.17"
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


