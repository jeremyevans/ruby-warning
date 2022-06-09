require_relative 'test_helper'

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
    w = nil

    Warning.ignore(/global variable `\$test_warning_ignore' not initialized/)
    Warning.process do |warning|
      w = [4, warning]
    end
    Warning.freeze

    assert_raises RuntimeError do
      Warning.ignore(/global variable `\$test_warning_ignore' not initialized/)
    end
    assert_raises RuntimeError do
      Warning.process{|warning| w = [4, warning]}
    end

    assert_warning '' do
      $test_warning_ignore
    end
    assert_nil w

    assert_warning '' do
      $test_warning_ignore2
    end
    assert_equal(4, w.first)
    assert_match(/global variable `\$test_warning_ignore2' not initialized/, w.last)
  end
end
