require 'minitest/unit'
require 'minitest/autorun'

class WarningTest < Minitest::Test
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

    assert_warning /instance variable @ivar not initialized/ do
      assert_nil(obj.instance_variable_get(:@ivar))
    end

    require 'warning'

    assert_warning /instance variable @ivar not initialized/ do
      assert_nil(obj.instance_variable_get(:@ivar))
    end

    Warning.ignore(/instance variable @ivar not initialized/)

    assert_warning '' do
      assert_nil(obj.instance_variable_get(:@ivar))
    end

    assert_warning /instance variable @ivar2 not initialized/ do
      assert_nil(obj.instance_variable_get(:@ivar2))
    end

    Warning.ignore(/instance variable @ivar2 not initialized/, __FILE__)

    assert_warning '' do
      assert_nil(obj.instance_variable_get(:@ivar2))
    end

    assert_warning /instance variable @ivar3 not initialized/ do
      assert_nil(obj.instance_variable_get(:@ivar3))
    end

    Warning.ignore(/instance variable @ivar3 not initialized/, __FILE__+'a')

    assert_warning /instance variable @ivar3 not initialized/ do
      assert_nil(obj.instance_variable_get(:@ivar3))
    end

    Warning.clear

    assert_warning /instance variable @ivar not initialized/ do
      assert_nil(obj.instance_variable_get(:@ivar))
    end
  ensure
    Warning.clear
  end

  def test_warning_process
    obj = Object.new
    warn = nil

    require 'warning'

    Warning.process(__FILE__+'a') do |warning|
      warn = [0, warning]
    end

    assert_warning /instance variable @ivar not initialized/ do
      assert_nil(obj.instance_variable_get(:@ivar))
    end
    assert_nil(warn)

    Warning.process(__FILE__) do |warning|
      warn = [1, warning]
    end

    assert_warning '' do
      assert_nil(obj.instance_variable_get(:@ivar2))
    end
    assert_equal(1, warn.first)
    assert_match(/instance variable @ivar2 not initialized/, warn.last)
    warn = nil

    Warning.process(File.dirname(__FILE__)) do |warning|
      warn = [2, warning]
    end

    assert_warning '' do
      assert_nil(obj.instance_variable_get(:@ivar3))
    end
    assert_equal(1, warn.first)
    assert_match(/instance variable @ivar3 not initialized/, warn.last)
    warn = nil

    Warning.process(__FILE__+':') do |warning|
      warn = [3, warning]
    end

    assert_warning '' do
      assert_nil(obj.instance_variable_get(:@ivar4))
    end
    assert_equal(3, warn.first)
    assert_match(/instance variable @ivar4 not initialized/, warn.last)
    warn = nil

    Warning.clear

    assert_warning /instance variable @ivar5 not initialized/ do
      assert_nil(obj.instance_variable_get(:@ivar5))
    end
    assert_nil(warn)

    Warning.process do |warning|
      warn = [4, warning]
    end

    assert_warning '' do
      assert_nil(obj.instance_variable_get(:@ivar6))
    end
    assert_equal(4, warn.first)
    assert_match(/instance variable @ivar6 not initialized/, warn.last)
  ensure
    Warning.clear
  end
end
