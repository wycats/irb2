#
#   irb.rb - irb main module
#       $Release Version: 0.9.5 $
#       $Revision: 15408 $
#       $Date: 2008-02-09 00:44:54 +0900 (Sat, 09 Feb 2008) $
#       by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#

require "irb/init"
require "irb/context"
require "irb/extend-command"

require "irb/ruby-lex"
require "irb/input-method"
require "irb/locale"
require "irb/colorize"

STDOUT.sync = true

module IRB
  class Abort < Exception; end
  class CommandResult
    def self.===(other)
      other == self || other.kind_of?(IRB::Irb)
    end
  end

  class << self
    attr_reader   :conf
    attr_accessor :main_context

    def pause
      sleep
      STDOUT.flush
      STDERR.flush
    end

    def version
      @version ||= begin
        require "irb/version"
        version = RELEASE_VERSION.sub(/\.0/, "")
        format("irb %s(%s)", version, LAST_UPDATE_DATE)
      end
    end

    def start(path = nil)
      $0 = File.basename(path, ".rb") if path

      setup(path)

      irb = Irb.new(nil, conf[:SCRIPT])

      self.main_context = irb.context

      # TODO: Move into history module
      main_context.save_history = conf[:SAVE_HISTORY]

      require "irb/ext/multi-irb"

      trap("SIGINT") { irb.signal_handle }
      catch(:irb_exit) { irb.eval_input }
    end

    def current_context
      main_context
    end

    def irb_exit(ret)
      throw :irb_exit, ret
    end

    def irb_abort(irb, exception = Abort)
      irb.context.thread.raise exception, "abort then interrupt!!"
    end
  end

  @conf = {}

  #
  # irb interpreter main routine
  #
  class Irb
    def initialize(workspace = nil, input_method = nil, output_method = nil)
      @context = Context.new(self, workspace, input_method, output_method)
      @context.main.extend ExtendCommandBundle
      @signal_status = :IN_IRB

      @scanner = RubyLex.new
      @scanner.exception_on_syntax_error = false
      @stdout = STDOUT
    end

    attr_reader :context
    attr_accessor :scanner

    def handle_exception(exc)
      return unless exc

      print exc.class, ": ", exc, "\n"

      irb_bug = exc.backtrace[0] =~ /irb(2)?(\/.*|-.*|\.rb)?:/ && exc.class.to_s !~ /^IRB/

      exc.backtrace.each do |line|
        line = @context.workspace.filter_backtrace(line) unless irb_bug
        puts "\tfrom #{line}" if line
      end

      puts "Maybe IRB bug!" if irb_bug
    end

    def eval_input
      context.set_prompt(scanner)
      set_input

      @scanner.each_top_level_statement do |line, line_no|
        with_signal_status(:IN_EVAL) do
          begin
            @context.evaluate(line, line_no)
          rescue Interrupt => e
            handle_exception(e)
          rescue SystemExit, SignalException
            raise
          rescue Exception => e
            handle_exception(e)
          end
        end
      end
    end

    def set_input
      scanner.set_input do
        with_signal_status(:IN_INPUT) { context.io.gets || "\n" }
      end
    end

    def signal_handle
      case @signal_status
      when :IN_INPUT
        puts "^C"
        raise RubyLex::TerminateLineInput
      when :IN_EVAL
        IRB.irb_abort(self)
      when :IN_LOAD
        puts "\nabort!!" if @context.verbose?
        IRB.irb_abort(self, LoadAbort)
      when :IN_IRB
        # ignore
      else
        # ignore other cases as well
      end
    end

    def with_signal_status(status)
      return yield if @signal_status == :IN_LOAD

      old_signal_status, @signal_status = @signal_status, status

      begin
        yield
      ensure
        @signal_status = old_signal_status if $SAFE.zero?
      end
    end

    def inspect
      ivars = instance_variables.inject([]) do |ary, name|
        ary << "#{name}=#{instance_variable_get(name)}"
      end
      format("#<%s: %s>", self.class, ivars.join(", "))
    end
  end
end
