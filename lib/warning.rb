require 'monitor'

module Warning
  module Processor
    # Map of symbols to regexps for warning messages to ignore.
    IGNORE_MAP = {
      uninitialized_instance_variable: /: warning: instance variable @.+ not initialized\n\z/,
      method_redefined: /: warning: method redefined; discarding old .+\n\z|: warning: previous definition of .+ was here\n\z/
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
    # The regexp can also be one of the following symbols, which will
    # use an appropriate regexp for the given warning:
    #
    # :uninitialized_instance_variable :: Ignore warning messages for accesses to instance variables
    #                                     that have not yet been initialized
    # :method_redefined :: Ignore warning messages when defining a method in a class/module where a
    #                      method of the same name was already defined in that class/module.
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
    #   Warning.ignore(:uninitialized_instance_variable, __FILE__)
    def ignore(regexp, path='')
      regexp = IGNORE_MAP.fetch(regexp) if regexp.is_a?(Symbol)

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
