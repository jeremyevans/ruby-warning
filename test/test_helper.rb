if coverage_type = ENV.delete('COVERAGE')
  require 'simplecov'

  SimpleCov.start do
    command_name coverage_type
    coverage :line
    coverage :branch
    cover "lib/**/*.rb"
    group('Missing'){|src| src.covered_percent < 100}
    merge_timeout 600
  end
end

ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
require 'minitest/global_expectations/autorun'
require_relative '../lib/warning'
