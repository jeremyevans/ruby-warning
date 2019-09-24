ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
require 'minitest/global_expectations/autorun'
require 'warning'

class WarningFreezeTest < Minitest::Test
  module EnvUtil
    def verbose_warning
      class << (stderr = "")
        alias write <<
      end
      stderr, $stderr, verbose, $VERBOSE = $stderr, stderr, $VERBOSE, true
      yield stderr
      return $stderr
    ensure
      stderr, $stderr, $VERBOSE = $stderr, stderr, verbose
    end
    module_function :verbose_warning

    def with_default_internal(enc)
      verbose, $VERBOSE = $VERBOSE, nil
      origenc, Encoding.default_internal = Encoding.default_internal, enc
      $VERBOSE = verbose
      yield
    ensure
      verbose, $VERBOSE = $VERBOSE, nil
      Encoding.default_internal = origenc
      $VERBOSE = verbose
    end
    module_function :with_default_internal
  end

  def assert_warning(pat, msg = nil)
    stderr = EnvUtil.verbose_warning {
      EnvUtil.with_default_internal(pat.encoding) {
        yield
      }
    }
    msg = message(msg) {diff pat, stderr}
    assert(pat === stderr, msg)
  end

  def test_warning_ignore
    obj = Object.new
    w = nil

    Warning.ignore(/instance variable @ivar not initialized/)
    Warning.process do |warning|
      w = [4, warning]
    end
    Warning.freeze

    assert_raises RuntimeError do
      Warning.ignore(/instance variable @ivar not initialized/)
    end
    assert_raises RuntimeError do
      Warning.process{|warning| w = [4, warning]}
    end

    assert_warning '' do
      assert_nil(obj.instance_variable_get(:@ivar))
    end
    assert_nil w

    assert_warning '' do
      assert_nil(obj.instance_variable_get(:@ivar6))
    end
    assert_equal(4, w.first)
    assert_match(/instance variable @ivar6 not initialized/, w.last)
  end
end
