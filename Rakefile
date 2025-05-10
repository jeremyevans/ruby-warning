require "rake"
require "rake/clean"

CLEAN.include ["warning-*.gem", "rdoc"]

desc "Build warning gem"
task :package=>[:clean] do |p|
  sh %{#{FileUtils::RUBY} -S gem build warning.gemspec}
end

### Specs

desc "Run tests"
task :test do
  sh "#{FileUtils::RUBY} -w #{'-W:strict_unused_block' if RUBY_VERSION >= '3.4'} test/test_warning.rb"
end

desc "Run tests with frozen Warning"
task :test_freeze do
  sh "#{FileUtils::RUBY} -w #{'-W:strict_unused_block' if RUBY_VERSION >= '3.4'} test/test_freeze_warning.rb"
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

desc "Generate rdoc"
task :rdoc do
  rdoc_dir = "rdoc"
  rdoc_opts = ["--line-numbers", "--inline-source", '--title', 'ruby-warning: Add custom processing for warnings']

  begin
    gem 'hanna'
    rdoc_opts.concat(['-f', 'hanna'])
  rescue Gem::LoadError
  end

  rdoc_opts.concat(['--main', 'README.rdoc', "-o", rdoc_dir] +
    %w"README.rdoc CHANGELOG MIT-LICENSE" +
    Dir["lib/**/*.rb"]
  )

  FileUtils.rm_rf(rdoc_dir)

  require "rdoc"
  RDoc::RDoc.new.document(rdoc_opts)
end
