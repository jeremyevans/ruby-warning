ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
require 'minitest/global_expectations/autorun'
require 'warning'
require 'pathname'

class WarningTest < Minitest::Test
  module EnvUtil
    def verbose_warning
      stderr = ""
      class << (stderr = "")
        alias write <<
        def puts(*a)
          self << a.join("\n")
        end
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

  def ivar
    Object.new.instance_variable_get(:@ivar)
  end

  def test_warning_dedup
    assert_warning(/instance variable @ivar not initialized/) do
      ivar
    end
    assert_warning(/instance variable @ivar not initialized/) do
      ivar
    end

    Warning.dedup

    assert_warning(/instance variable @ivar not initialized/) do
      ivar
    end
    assert_warning('') do
      ivar
    end
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
  end if RUBY_VERSION < '2.6'

  if RUBY_VERSION > '2.7' && RUBY_VERSION < '2.8'
    def h2kw(**kw)
    end
    def kw2h(h, **kw)
    end
    def skw(h=1, a: 1)
    end

    def test_warning_ignore_keyword
      assert_warning(/warning: Using the last argument as keyword parameters is deprecated; maybe \*\* should be added to the call.*The called method `h2kw' is defined here/m) do
        h2kw({})
      end
      assert_warning(/warning: Passing the keyword argument as the last hash parameter is deprecated.*The called method `kw2h' is defined here/m) do
        kw2h(a: 1)
      end
      assert_warning(/warning: Splitting the last argument into positional and keyword parameters is deprecated.*The called method `skw' is defined here/m) do
        skw("b" => 1, a: 2)
      end
      assert_warning(/warning: Splitting the last argument into positional and keyword parameters is deprecated.*The called method `skw' is defined here/m) do
        skw({"b" => 1, a: 2})
      end

      Warning.ignore(:keyword_separation, __FILE__)

      assert_warning '' do
        h2kw({})
        kw2h(a: 1)
        skw("b" => 1, a: 2)
        skw({"b" => 1, a: 2})
      end
    end

    def test_warning_ignore_safe
      assert_warning(/\$SAFE will become a normal global variable in Ruby 3\.0/) do
        $SAFE = 0
      end

      Warning.ignore(:safe, __FILE__)

      assert_warning("") do
        $SAFE = 0
      end
    end
  end

  if RUBY_VERSION > '2.7' && RUBY_VERSION < '3.2'

    def test_warning_ignore_taint
      o = Object.new

      assert_warning(/Object#taint is deprecated and will be removed in Ruby 3\.2/) do
        o.taint
      end
      assert_warning(/Object#untaint is deprecated and will be removed in Ruby 3\.2/) do
        o.untaint
      end
      assert_warning(/Object#tainted\? is deprecated and will be removed in Ruby 3\.2/) do
        o.tainted?
      end
      assert_warning(/Object#trust is deprecated and will be removed in Ruby 3\.2/) do
        o.trust
      end
      assert_warning(/Object#untrust is deprecated and will be removed in Ruby 3\.2/) do
        o.untrust
      end
      assert_warning(/Object#untrusted\? is deprecated and will be removed in Ruby 3\.2/) do
        o.untrusted?
      end

      path = Pathname.new(__FILE__)
      assert_warning(/Pathname#taint is deprecated and will be removed in Ruby 3\.2/) do
        path.taint
      end
      assert_warning(/Pathname#untaint is deprecated and will be removed in Ruby 3\.2/) do
        path.untaint
      end

      Warning.ignore(:taint, __FILE__)

      assert_warning("") do
        o.taint
        o.untaint
        o.tainted?
        o.trust
        o.untrust
        o.untrusted?
        p.taint
        p.untaint
      end
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

  def test_warning_ignore_mismatched_indentation
    assert_warning(/warning: mismatched indentations/) do
      load 'test/fixtures/mismatched_indentations.rb'
    end

    Warning.ignore(:mismatched_indentations, 'test/fixtures/mismatched_indentations.rb')

    assert_warning '' do
      load 'test/fixtures/mismatched_indentations.rb'
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

  def test_warning_process_block_return_default
    w = nil
    Warning.process(__FILE__) do |warning|
      w = warning
      :default
    end

    assert_warning(/instance variable @ivar not initialized/) do
      ivar
    end
    assert_match(/instance variable @ivar not initialized/, w)
  end

  def test_warning_process_block_return_backtrace
    w = nil
    Warning.process(__FILE__) do |warning|
      w = warning
      :backtrace
    end

    assert_warning(/instance variable @ivar not initialized.*#{__FILE__}/m) do
      ivar
    end
    assert_match(/instance variable @ivar not initialized/, w)
  end

  def test_warning_process_block_return_raise
    w = nil
    Warning.process(__FILE__) do |warning|
      w = warning
      :raise
    end

    assert_raises(RuntimeError, /instance variable @ivar not initialized/) do
      EnvUtil.verbose_warning{ivar}
    end
    assert_match(/instance variable @ivar not initialized/, w)
  end

  def test_warning_process_action
    w = nil
    Warning.process(__FILE__, :missing_ivar=>:default, :missing_gvar=>:backtrace, :ambiguous_slash=>:raise)
    Warning.process(__FILE__, :not_reached=>proc do |warning|
      w = warning
      :raise
    end)

    assert_warning(/instance variable @ivar not initialized/) do
      ivar
    end

    assert_warning(/global variable `\$gvar' not initialized.*#{__FILE__}/m) do
      $gvar
    end

    Warning.process(__FILE__) do |warning|
      w = warning
      :raise
    end

    assert_raises(RuntimeError, /warning: ambiguous first argument; put parentheses or a space even after `\/' operator/) do
      EnvUtil.verbose_warning{instance_eval('d /a/', __FILE__)}
    end

    assert_raises(RuntimeError, /warning: statement not reached/) do
      EnvUtil.verbose_warning{instance_eval('def self.b; return; 1 end', __FILE__)}
    end
    assert_match(/warning: statement not reached/, w)
  end

  def test_warning_process_action_and_block
    assert_raises(ArgumentError) do
      Warning.process(__FILE__)
    end
  end

  def test_warning_process_no_action_and_no_block
    assert_raises(ArgumentError) do
      Warning.process(__FILE__, :missing_ivar=>:default){}
    end
  end
end
