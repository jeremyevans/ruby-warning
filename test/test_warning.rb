require 'minitest/autorun'
require 'warning'

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

  def teardown
    Warning.clear
  end

  def test_warning_ignore
    obj = Object.new

    assert_warning(/instance variable @ivar not initialized/) do
      assert_nil(obj.instance_variable_get(:@ivar))
    end

    assert_warning(/instance variable @ivar not initialized/) do
      assert_nil(obj.instance_variable_get(:@ivar))
    end

    Warning.ignore(/instance variable @ivar not initialized/)

    assert_warning '' do
      assert_nil(obj.instance_variable_get(:@ivar))
    end

    assert_warning(/instance variable @ivar2 not initialized/) do
      assert_nil(obj.instance_variable_get(:@ivar2))
    end

    Warning.ignore(/instance variable @ivar2 not initialized/, __FILE__)

    assert_warning '' do
      assert_nil(obj.instance_variable_get(:@ivar2))
    end

    assert_warning(/instance variable @ivar3 not initialized/) do
      assert_nil(obj.instance_variable_get(:@ivar3))
    end

    Warning.ignore(/instance variable @ivar3 not initialized/, __FILE__+'a')

    assert_warning(/instance variable @ivar3 not initialized/) do
      assert_nil(obj.instance_variable_get(:@ivar3))
    end
  end

  def test_warning_ignore_missing_ivar
    Warning.clear

    assert_warning(/instance variable @ivar not initialized/) do
      assert_nil(instance_variable_get(:@ivar))
    end

    Warning.ignore(:missing_ivar, __FILE__)

    assert_warning '' do
      assert_nil(instance_variable_get(:@ivar))
    end
  end

  def test_warning_ignore_missing_gvar
    assert_warning(/global variable `\$gvar' not initialized/) do
      $gvar
    end

    Warning.ignore(:missing_gvar, __FILE__)

    assert_warning '' do
      $gvar
    end
  end

  def test_warning_ignore_method_redefined
    def self.a; end

    assert_warning(/method redefined; discarding old a.+previous definition of a was here/m) do
      def self.a; end
    end

    Warning.ignore(:method_redefined, __FILE__)

    assert_warning '' do
      def self.a; end
    end
  end

  def test_warning_ignore_not_reached
    assert_warning(/: warning: statement not reached/) do
      instance_eval('def self.b; return; 1 end', __FILE__)
    end

    Warning.ignore(:not_reached, __FILE__)

    assert_warning '' do
      instance_eval('def self.c; return; 1 end', __FILE__)
    end
  end

  def test_warning_ignore_fixnum
    assert_warning(/warning: constant ::Fixnum is deprecated/) do
      ::Fixnum
    end

    Warning.ignore(:fixnum, __FILE__)

    assert_warning '' do
      ::Fixnum
    end
  end

  def test_warning_ignore_bignum
    assert_warning(/warning: constant ::Bignum is deprecated/) do
      ::Bignum
    end

    Warning.ignore(:bignum, __FILE__)

    assert_warning '' do
      ::Bignum
    end
  end

  def test_warning_ignore_ambiguous_slash
    def self.d(re); end
    assert_warning(/warning: ambiguous first argument; put parentheses or a space even after `\/' operator/) do
      instance_eval('d /a/', __FILE__)
    end

    Warning.ignore(:ambiguous_slash, __FILE__)

    assert_warning '' do
      instance_eval('d /a/', __FILE__)
    end
  end

  def test_warning_ignore_unused_var
    assert_warning(/warning: assigned but unused variable - \w+/) do
      instance_eval('def self.e; b = 1; 2 end', __FILE__)
    end

    Warning.ignore(:unused_var, __FILE__)

    assert_warning '' do
      instance_eval('def self.f; b = 1; 2 end', __FILE__)
    end
  end

  def test_warning_ignore_useless_operator
    assert_warning(/warning: possibly useless use of == in void context/) do
      instance_eval('1 == 2; true', __FILE__)
    end

    Warning.ignore(:useless_operator, __FILE__)

    assert_warning '' do
      instance_eval('1 == 2; true', __FILE__)
    end
  end

  def test_warning_ignore_arg_prefix
    assert_warning(/: warning: `\*' interpreted as argument prefix/) do
      instance_eval('Array *[nil]', __FILE__)
    end

    assert_warning(/: warning: `&' interpreted as argument prefix/) do
      instance_eval('tap &proc{}', __FILE__)
    end
    Warning.ignore(:arg_prefix, __FILE__)

    assert_warning '' do
      instance_eval('Array *[nil]', __FILE__)
      instance_eval('tap &proc{}', __FILE__)
    end
  end

  def test_warning_ignore_shadow
    assert_warning(/warning: shadowing outer local variable - a/) do
      instance_eval('lambda{|a| lambda{|a|}}', __FILE__)
    end

    Warning.ignore(:shadow, __FILE__)

    assert_warning '' do
      instance_eval('lambda{|a| lambda{|a|}}', __FILE__)
    end
  end

  def test_warning_ignore_symbol_array
    def self.c; end

    assert_warning(/statement not reached.+method redefined; discarding old c.+previous definition of c was here/m) do
      instance_eval('def self.c; return; 1 end', __FILE__)
    end

    Warning.ignore([:method_redefined, :not_reached], __FILE__)

    assert_warning '' do
      instance_eval('def self.c; return; 1 end', __FILE__)
    end
  end

  def test_warning_process
    obj = Object.new
    warn = nil

    Warning.process(__FILE__+'a') do |warning|
      warn = [0, warning]
    end

    assert_warning(/instance variable @ivar not initialized/) do
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

    assert_warning(/instance variable @ivar5 not initialized/) do
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
  end
end
