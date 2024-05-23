require_relative 'test_helper'
require 'pathname'

class WarningTest < Minitest::Test
  module EnvUtil
    def verbose_warning
      stderr = String.new
      class << stderr
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

  def test_warning_clear_ignore
    Warning.ignore(/.*/)

    assert_warning '' do
      Warning.warn 'foo'
    end

    Warning.clear do
      assert_warning 'foo' do
        Warning.warn 'foo'
      end
    end

    assert_warning '' do
      Warning.warn 'foo'
    end

    Warning.clear

    assert_warning 'foo' do
      Warning.warn 'foo'
    end
  end

  def test_warning_clear_process
    Warning.process('', /foo/ => :raise)

    e = assert_raises(RuntimeError) do
      Warning.warn 'foo'
    end
    assert_equal('foo', e.message)

    Warning.clear do
      assert_warning 'foo' do
        Warning.warn 'foo'
      end
    end

    e = assert_raises(RuntimeError) do
      Warning.warn 'foo'
    end
    assert_equal('foo', e.message)

    Warning.clear

    assert_warning 'foo' do
      Warning.warn 'foo'
    end
  end

  def test_warning_clear_dedup
    Warning.dedup

    assert_warning 'foo' do
      Warning.warn 'foo'
    end

    assert_warning '' do
      Warning.warn 'foo'
    end

    Warning.clear do
      assert_warning 'foo' do
        Warning.warn 'foo'
      end

      assert_warning 'foo' do
        Warning.warn 'foo'
      end
    end

    assert_warning '' do
      Warning.warn 'foo'
    end

    Warning.clear

    assert_warning 'foo' do
      Warning.warn 'foo'
    end

    assert_warning 'foo' do
      Warning.warn 'foo'
    end
  end

  def test_warning_dedup
    gvar = ->{$test_warning_dedup}

    assert_warning(/global variable [`']\$test_warning_dedup' not initialized/) do
      gvar.call
    end
    assert_warning(/global variable [`']\$test_warning_dedup' not initialized/) do
      gvar.call
    end

    Warning.dedup

    assert_warning(/global variable [`']\$test_warning_dedup' not initialized/) do
      gvar.call
    end
    assert_warning('') do
      gvar.call
    end
  end

  def test_warning_ignore
    assert_warning(/global variable [`']\$test_warning_ignore' not initialized/) do
      assert_nil($test_warning_ignore)
    end

    Warning.ignore(/global variable [`']\$test_warning_ignore' not initialized/)

    assert_warning '' do
      assert_nil($test_warning_ignore)
    end

    assert_warning(/global variable [`']\$test_warning_ignore2' not initialized/) do
      assert_nil($test_warning_ignore2)
    end

    Warning.ignore(/global variable [`']\$test_warning_ignore2' not initialized/, __FILE__)

    assert_warning '' do
      assert_nil($test_warning_ignore2)
    end

    assert_warning(/global variable [`']\$test_warning_ignore3' not initialized/) do
      assert_nil($test_warning_ignore3)
    end

    Warning.ignore(/global variable [`']\$test_warning_ignore3' not initialized/, __FILE__ + 'a')

    assert_warning(/global variable [`']\$test_warning_ignore3' not initialized/) do
      assert_nil($test_warning_ignore3)
    end

    assert_raises(TypeError) do
      Warning.ignore(Object.new)
    end
  end

  def test_warning_ignore_missing_ivar
    Warning.clear

    unless RUBY_VERSION >= '3.0'
      assert_warning(/instance variable @ivar not initialized/) do
        assert_nil(instance_variable_get(:@ivar))
      end
    end

    Warning.ignore(:missing_ivar, __FILE__)

    assert_warning '' do
      assert_nil(instance_variable_get(:@ivar))
    end
  end

  def test_warning_ignore_missing_gvar
    assert_warning(/global variable [`']\$gvar' not initialized/) do
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
  end if RUBY_VERSION < '3.2'

  def test_warning_ignore_bignum
    assert_warning(/warning: constant ::Bignum is deprecated/) do
      ::Bignum
    end

    Warning.ignore(:bignum, __FILE__)

    assert_warning '' do
      ::Bignum
    end
  end if RUBY_VERSION < '3.2'

  def test_warning_ignore_void_context
    assert_warning(/warning: possibly useless use of :: in void context/) do
      instance_eval('::Object; nil', __FILE__, __LINE__)
    end

    Warning.ignore(:void_context, __FILE__)

    assert_warning '' do
      instance_eval('::Object; nil', __FILE__, __LINE__)
    end

    assert_warning '' do
      instance_eval('Object; nil', __FILE__, __LINE__)
    end

    assert_warning '' do
      instance_eval('v = 0; v; nil', __FILE__, __LINE__)
    end

    assert_warning '' do
      instance_eval('1 > 1; nil', __FILE__, __LINE__)
    end

    assert_warning '' do
      instance_eval('defined? C; nil', __FILE__, __LINE__)
    end

    if RUBY_VERSION >= '2.6'
      assert_warning '' do
        instance_eval('1..; nil', __FILE__, __LINE__)
      end
    end
  end

  def test_warning_ignore_ambiguous_slash
    def self.d(re); end
    assert_warning(/warning: ambi/) do
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
    assert_warning(/: warning: [`']\*' interpreted as argument prefix/) do
      instance_eval('Array *[nil]', __FILE__)
    end

    assert_warning(/: warning: [`']&' interpreted as argument prefix/) do
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
      assert_warning(/warning: Using the last argument as keyword parameters is deprecated; maybe \*\* should be added to the call.*The called method [`']h2kw' is defined here/m) do
        h2kw({})
      end
      assert_warning(/warning: Passing the keyword argument as the last hash parameter is deprecated.*The called method [`']kw2h' is defined here/m) do
        kw2h(a: 1)
      end
      assert_warning(/warning: Splitting the last argument into positional and keyword parameters is deprecated.*The called method [`']skw' is defined here/m) do
        skw("b" => 1, a: 2)
      end
      assert_warning(/warning: Splitting the last argument into positional and keyword parameters is deprecated.*The called method [`']skw' is defined here/m) do
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

  def test_warning_ignore_ignored_block
    Warning.clear

    def self.foo_test_warning_ignore_ignored_block; end

    if RUBY_VERSION >= '3.4'
      assert_warning(/the block passed to '.*foo_test_warning_ignore_ignored_block' defined at #{__FILE__}:#{__LINE__-3} may be ignored/) do
        assert_nil(foo_test_warning_ignore_ignored_block{})
      end
    end

    Warning.ignore(:ignored_block, __FILE__)

    assert_warning '' do
      assert_nil(foo_test_warning_ignore_ignored_block{})
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
    warn = nil

    Warning.process(__FILE__+'a') do |warning|
      warn = [0, warning]
    end

    assert_warning(/global variable [`']\$test_warning_process' not initialized/) do
      $test_warning_process
    end
    assert_nil(warn)

    Warning.process(__FILE__) do |warning|
      warn = [1, warning]
    end

    assert_warning '' do
      $test_warning_process2
    end
    assert_equal(1, warn.first)
    assert_match(/global variable [`']\$test_warning_process2' not initialized/, warn.last)
    warn = nil

    Warning.process(File.dirname(__FILE__)) do |warning|
      warn = [2, warning]
    end

    assert_warning '' do
      $test_warning_process3
    end
    assert_equal(1, warn.first)
    assert_match(/global variable [`']\$test_warning_process3' not initialized/, warn.last)
    warn = nil

    Warning.process(__FILE__+':') do |warning|
      warn = [3, warning]
    end

    assert_warning '' do
      $test_warning_process4
    end
    assert_equal(3, warn.first)
    assert_match(/global variable [`']\$test_warning_process4' not initialized/, warn.last)
    warn = nil

    Warning.clear

    assert_warning(/global variable [`']\$test_warning_process5' not initialized/) do
      $test_warning_process5
    end
    assert_nil(warn)

    Warning.process do |warning|
      warn = [4, warning]
    end

    assert_warning '' do
      $test_warning_process6
    end
    assert_equal(4, warn.first)
    assert_match(/global variable [`']\$test_warning_process6' not initialized/, warn.last)

    assert_raises(TypeError) do
      Warning.process('', Object.new=>:raise)
    end
  end

  def test_warning_process_block_return_default
    w = nil
    Warning.process(__FILE__) do |warning|
      w = warning
      :default
    end

    assert_warning(/global variable [`']\$test_warning_process_block_return_default' not initialized/) do
      $test_warning_process_block_return_default
    end
    assert_match(/global variable [`']\$test_warning_process_block_return_default' not initialized/, w)
  end

  def test_warning_process_block_return_backtrace
    w = nil
    Warning.process(__FILE__) do |warning|
      w = warning
      :backtrace
    end

    assert_warning(/global variable [`']\$test_warning_process_block_return_backtrace' not initialized.*#{__FILE__}/m) do
      $test_warning_process_block_return_backtrace
    end
    assert_match(/global variable [`']\$test_warning_process_block_return_backtrace' not initialized/, w)
  end

  def test_warning_process_block_return_raise
    w = nil
    Warning.process(__FILE__) do |warning|
      w = warning
      :raise
    end

    assert_raises(RuntimeError) do
      $test_warning_process_block_return_raise
    end
    assert_match(/global variable [`']\$test_warning_process_block_return_raise' not initialized/, w)
  end

  def test_warning_process_action
    Warning.process(__FILE__, :method_redefined=>:default, :missing_gvar=>:backtrace, :ambiguous_slash=>:raise)
    Warning.process(__FILE__, :not_reached=>proc do |warning|
      :raise
    end)

    assert_warning(/warning: method redefined/) do
      Class.new do
        def a; end
        def a; end
      end
    end

    assert_warning(/global variable [`']\$test_warning_process_action' not initialized.*#{__FILE__}/m) do
      $test_warning_process_action
    end

    e = assert_raises(RuntimeError) do
      EnvUtil.verbose_warning{instance_eval('d /a/', __FILE__)}
    end
    assert_includes(e.message, "warning: ambi")

    e = assert_raises(RuntimeError) do
      EnvUtil.verbose_warning{instance_eval('def self.b; return; 1 end', __FILE__)}
    end
    assert_includes(e.message, "warning: statement not reached")
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

  def test_warning_process_path_no_string
    e = assert_raises(ArgumentError) do
      Warning.process(/foo/) { :raise }
    end
    assert_includes(e.message, "path must be a String (given an instance of Regexp)")
  end

  if RUBY_VERSION >= '3.0'
    def test_warning_warn_category_keyword
      assert_warning('foo') do
        Warning.warn("foo", category: :deprecated)
      end
    end
  end
end
