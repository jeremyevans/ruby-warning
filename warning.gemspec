spec = Gem::Specification.new do |s|
  s.name = 'warning'
  s.version = '1.5.0'
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ["README.rdoc", "CHANGELOG", "MIT-LICENSE"]
  s.rdoc_options += ["--quiet", "--line-numbers", "--inline-source", '--title', 'ruby-warning: Add custom processing for warnings', '--main', 'README.rdoc']
  s.license = "MIT"
  s.summary = "Add custom processing for warnings"
  s.author = "Jeremy Evans"
  s.email = "code@jeremyevans.net"
  s.homepage = "https://github.com/jeremyevans/ruby-warning"
  s.required_ruby_version = ">= 2.4.0"
  s.files = %w(MIT-LICENSE CHANGELOG README.rdoc) + Dir["lib/**/*.rb"]
  s.description = <<END
ruby-warning adds custom processing for warnings, including the
ability to ignore specific warning messages, ignore warnings
in specific files/directories, include backtraces with warnings,
treat warnings as errors, deduplicate warnings, and add
custom handling for all warnings in specific files/directories.
END
  s.add_development_dependency "minitest-global_expectations"
  s.metadata = {
    'bug_tracker_uri'   => 'https://github.com/jeremyevans/ruby-warning/issues',
    'changelog_uri'     => 'https://github.com/jeremyevans/ruby-warning/blob/master/CHANGELOG',
    'documentation_uri' => 'https://github.com/jeremyevans/ruby-warning/blob/master/README.rdoc',
    'source_code_uri'   => 'https://github.com/jeremyevans/ruby-warning',
  }
end
