require "rake"
require "rake/clean"
require "rdoc/task"

CLEAN.include ["warning-*.gem", "rdoc"]

desc "Build warning gem"
task :package=>[:clean] do |p|
  sh %{#{FileUtils::RUBY} -S gem build warning.gemspec}
end

### Specs

desc "Run tests"
task :test do
  sh "#{FileUtils::RUBY} -w test/test_warning.rb"
end

desc "Run tests with frozen Warning"
task :test_freeze do
  sh "#{FileUtils::RUBY} -w test/test_freeze_warning.rb"
end

desc "Run tests with coverage"
task :test_cov do
  ENV['COVERAGE'] = 'regular'
  sh "#{FileUtils::RUBY} -w test/test_warning.rb"
  ENV['COVERAGE'] = 'frozen'
  sh "#{FileUtils::RUBY} -w test/test_freeze_warning.rb"
end

desc "Run all tests"
task :default=>[:test, :test_freeze]

### RDoc

RDOC_OPTS = ['--main', 'README.rdoc', "--quiet", "--line-numbers", "--inline-source", '--title', 'ruby-warning: Add custom processing for warnings']

begin
  gem 'hanna'
  RDOC_OPTS.concat(['-f', 'hanna'])
rescue Gem::LoadError
end


RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.options += RDOC_OPTS
  rdoc.rdoc_files.add %w"README.rdoc CHANGELOG MIT-LICENSE lib/**/*.rb"
end
