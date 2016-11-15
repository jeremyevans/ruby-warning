require 'monitor'

module Warning
  module Processor
    # Map of symbols to regexps for warning messages to ignore.
    IGNORE_MAP = {
      ambiguous_slash: /: warning: ambiguous first argument; put parentheses or a space even after `\/' operator\n\z/,
      bignum: /: warning: constant ::Bignum is deprecated\n\z/,
      fixnum: /: warning: constant ::Fixnum is deprecated\n\z/,
      method_redefined: /: warning: method redefined; discarding old .+\n\z|: warning: previous definition of .+ was here\n\z/,
      missing_gvar: /: warning: global variable `\$.+' not initialized\n\z/,
      missing_ivar: /: warning: instance variable @.+ not initialized\n\z/,
      not_reached: /: warning: statement not reached\n\z/,
      unused_var: /: warning: assigned but unused variable - \w+\n\z/,
    }

    # Clear all current ignored warnings and warning processors.
    def clear
      synchronize do
        @ignore.clear
        @process.clear
      end
    end
    
    # Ignore any warning messages matching the given regexp, if they
    # start with the given path.
    # The regexp can also be one of the following symbols (or an array including them), which will
    # use an appropriate regexp for the given warning:
    #
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
    # :unused_var :: Ignore warnings for unused variables.
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
    # not ignored and there is no warning processor setup for the warning
    # string, then use the default behavior of writing to $stderr.
    def warn(str)
      synchronize{@ignore.dup}.each do |path, regexp|
        if str.start_with?(path) && str =~ regexp
          return
        end
      end

      synchronize{@process.dup}.each do |path, block|
        if str.start_with?(path)
          block.call(str)
          return
        end
      end

      super
    end
  end

  @ignore = []
  @process = []

  extend MonitorMixin
  extend Processor
end
