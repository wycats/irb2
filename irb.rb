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
require "irb/output-method"
require "irb/locale"
require "irb/colorize"
require "irb/proxy"
require "pp"
require "stringio"

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

    def puts(*args)
      main_context.output_method.puts(*args)
      nil
    end

    def p(arg)
      puts arg.inspect
    end

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
      @stdout = STDOUT
    end

    attr_reader :context
    attr_accessor :scanner

    def handle_exception(exc)
      return unless exc

      reset_state

      print exc.class, ": ", exc, "\n"

      irb_bug = exc.backtrace[0] =~ /irb(2)?(\/.*|-.*|\.rb)?:/ && exc.class.to_s !~ /^IRB/

      exc.backtrace.each do |line|
        line = @context.workspace.filter_backtrace(line) unless irb_bug
        IRB.puts "\tfrom #{line}" if line
      end

      IRB.puts "Maybe IRB bug!" if irb_bug
    end

    def each_top_level_statement(&block)
      @lines << context.io.gets
      @line_number += 1
      yield @lines, @line_number
      each_top_level_statement(&block)
    end

    def reset_state
      @lines = ""
      @relative_line = 0
      @state = :finished
    end

    def eval_input
      @line_number = 1
      reset_state

      # TODO: Use the new prompt object
      context.io.prompt = IRB::DefaultPrompt.new
      context.io.prompt_state = [@state, @line_number, 0]

      each_top_level_statement do |line, line_no|
        # TODO: Lex to see if this is *ever* valid

        with_signal_status(:IN_EVAL) do
          begin
            @context.evaluate(line, line_no)
          rescue SyntaxError
            @state = :incomplete
            @relative_line += 1
          rescue Interrupt => e
            handle_exception(e)
          rescue SystemExit, SignalException
            raise
          rescue Exception => e
            handle_exception(e)
          else
            reset_state
          end
        end
        
        context.io.prompt_state = [@state, @line_number, @relative_line]
      end
    end

    def signal_handle
      case @signal_status
      when :IN_INPUT
        IRB.puts "^C"
        raise StandardError
      when :IN_EVAL
        IRB.irb_abort(self)
      when :IN_LOAD
        IRB.puts "\nabort!!" if @context.verbose?
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
