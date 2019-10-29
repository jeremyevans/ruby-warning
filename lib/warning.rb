require 'monitor'

module Warning
  module Processor
    # Map of symbols to regexps for warning messages to ignore.
    IGNORE_MAP = {
      ambiguous_slash: /: warning: ambiguous first argument; put parentheses or a space even after `\/' operator\n\z/,
      arg_prefix: /: warning: `[&\*]' interpreted as argument prefix\n\z/,
      bignum: /: warning: constant ::Bignum is deprecated\n\z/,
      fixnum: /: warning: constant ::Fixnum is deprecated\n\z/,
      method_redefined: /: warning: method redefined; discarding old .+\n\z|: warning: previous definition of .+ was here\n\z/,
      missing_gvar: /: warning: global variable `\$.+' not initialized\n\z/,
      missing_ivar: /: warning: instance variable @.+ not initialized\n\z/,
      not_reached: /: warning: statement not reached\n\z/,
      shadow: /: warning: shadowing outer local variable - \w+\n\z/,
      unused_var: /: warning: assigned but unused variable - \w+\n\z/,
      useless_operator: /: warning: possibly useless use of [><!=]+ in void context\n\z/,
      keyword_separation: /: warning: (?:The last argument is used as the keyword parameter|The keyword argument is passed as the last hash parameter|The last argument is split into positional and keyword parameters|The keyword argument for `.+' is passed as the last hash parameter|The last argument for `.+' is used as the keyword parameter|The last argument for `.+' is split into positional and keyword parameters|for (?:method|`.+') defined here)/,
    }

    # Clear all current ignored warnings, warning processors, and duplicate check cache.
    # Also disables deduplicating warnings if that is currently enabled.
    def clear
      synchronize do
        @ignore.clear
        @process.clear
        @dedup = false
      end
    end

    # Deduplicate warnings, supress warning messages if the same warning message
    # has already occurred.  Note that this can lead to unbounded memory use
    # if unique warnings are generated.
    def dedup
      @dedup = {}
    end

    def freeze
      @ignore.freeze
      @process.freeze
      super
    end
    
    # Ignore any warning messages matching the given regexp, if they
    # start with the given path.
    # The regexp can also be one of the following symbols (or an array including them), which will
    # use an appropriate regexp for the given warning:
    #
    # :arg_prefix :: Ignore warnings when using * or & as an argument prefix
    # :ambiguous_slash :: Ignore warnings for things like <tt>method /regexp/</tt>
    # :bignum :: Ignore warnings when referencing the ::Bignum constant.
    # :fixnum :: Ignore warnings when referencing the ::Fixnum constant.
    # :method_redefined :: Ignore warnings when defining a method in a class/module where a
    #                      method of the same name was already defined in that class/module.
    # :missing_gvar :: Ignore warnings for accesses to global variables
    #                  that have not yet been initialized
    # :missing_ivar :: Ignore warnings for accesses to instance variables
    #                  that have not yet been initialized
    # :not_reached :: Ignore statement not reached warnings.
    # :shadow :: Ignore warnings related to shadowing outer local variables.
    # :unused_var :: Ignore warnings for unused variables.
    # :useless_operator :: Ignore warnings when using operators such as == and > when the
    #                      result is not used.
    #
    # Examples:
    #
    #   # Ignore all uninitialized instance variable warnings
    #   Warning.ignore(/instance variable @\w+ not initialized/)
    #
    #   # Ignore all uninitialized instance variable warnings in current file
    #   Warning.ignore(/instance variable @\w+ not initialized/, __FILE__)
    #
    #   # Ignore all uninitialized instance variable warnings in current file
    #   Warning.ignore(:missing_ivar, __FILE__)
    #
    #   # Ignore all uninitialized instance variable and method redefined warnings in current file
    #   Warning.ignore([:missing_ivar, :method_redefined],  __FILE__)
    def ignore(regexp, path='')
      case regexp
      when Regexp
        # already regexp
      when Symbol
        regexp = IGNORE_MAP.fetch(regexp)
      when Array
        regexp = Regexp.union(regexp.map{|re| IGNORE_MAP.fetch(re)})
      else
        raise TypeError, "first argument to Warning.ignore should be Regexp, Symbol, or Array of Symbols, got #{regexp.inspect}"
      end

      synchronize do 
        @ignore << [path, regexp]
      end
      nil
    end

    # Handle all warnings starting with the given path, instead of
    # the default behavior of printing them to $stderr. Examples:
    #
    #   # Write warning to LOGGER at level warning
    #   Warning.process do |warning|
    #     LOGGER.warning(warning)
    #   end
    #
    #   # Write warnings in the current file to LOGGER at level error level
    #   Warning.process(__FILE__) do |warning|
    #     LOGGER.error(warning)
    #   end
    def process(path='', &block)
      synchronize do
        @process << [path, block]
        @process.sort_by!(&:first)
        @process.reverse!
      end
      nil
    end

    # Handle ignored warnings and warning processors.  If the warning is
    # not ignored, is not a duplicate warning (if checking for duplicates)
    # and there is no warning processor setup for the warning
    # string, then use the default behavior of writing to $stderr.
    def warn(str)
      synchronize{@ignore.dup}.each do |path, regexp|
        if str.start_with?(path) && str =~ regexp
          return
        end
      end

      if @dedup
        if synchronize{@dedup[str]}
          return
        end

        synchronize{@dedup[str] = true}
      end

      synchronize{@process.dup}.each do |path, block|
        if str.start_with?(path)
          block.call(str)
          return
        end
      end

      super
    end

    private

    def synchronize(&block)
      @monitor.synchronize(&block)
    end
  end

  @ignore = []
  @process = []
  @dedup = false
  @monitor = Monitor.new

  extend Processor
end
