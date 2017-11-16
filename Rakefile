require "rake"
require "rake/clean"
require 'rake/testtask'
require "rdoc/task"

CLEAN.include ["warning-*.gem", "rdoc"]

desc "Build warning gem"
task :package=>[:clean] do |p|
  sh %{#{FileUtils::RUBY} -S gem build warning.gemspec}
end

### Specs

desc "Run test"
Rake::TestTask.new do |t|
  t.libs.push "lib"
  t.test_files = FileList['test/test_warning.rb']
  t.verbose = true
end

desc "Run test"
Rake::TestTask.new(:test_freeze) do |t|
  t.libs.push "lib"
  t.test_files = FileList['test/test_freeze_warning.rb']
  t.verbose = true
end

desc "Run all tests"
task :default=>[:test, :test_freeze]

### RDoc

RDOC_OPTS = ['--main', 'README.rdoc', "--quiet", "--line-numbers", "--inline-source", '--title', 'ruby-warning: Add custom processing for warnings']

begin
  gem 'hanna-nouveau'
  RDOC_OPTS.concat(['-f', 'hanna'])
rescue Gem::LoadError
end


RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.options += RDOC_OPTS
  rdoc.rdoc_files.add %w"README.rdoc CHANGELOG MIT-LICENSE lib/**/*.rb"
end
