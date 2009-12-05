#
#   irb/context.rb - irb context
#       $Release Version: 0.9.5$
#       $Revision: 11708 $
#       $Date: 2007-02-13 08:01:19 +0900 (Tue, 13 Feb 2007) $
#       by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#
require "irb/workspace"

module IRB
  class Context
    #
    # Arguments:
    #   input_method: nil -- stdin or readline
    #                 String -- File
    #                 other -- using this as InputMethod
    #
    def initialize(irb, workspace = nil, input_method = nil, output_method = nil)
      @irb = irb
      @workspace = workspace || WorkSpace.new
      @thread = Thread.current

      # copy of default configuration
      @ap_name = IRB.conf[:AP_NAME]
      @rc = IRB.conf[:RC]

      @use_readline = IRB.conf[:USE_READLINE]

      # Extra modules
      self.math_mode = IRB.conf[:MATH_MODE] if IRB.conf[:MATH_MODE]
      self.use_tracer = IRB.conf[:USE_TRACER] if IRB.conf[:USE_TRACER]
      self.eval_history = IRB.conf[:EVAL_HISTORY] if IRB.conf[:EVAL_HISTORY]

      self.prompt_mode = IRB.conf[:PROMPT_MODE]

      case input_method
      when nil
        case use_readline?
        when nil
          if (defined?(ReadlineInputMethod) && STDIN.tty? &&
              IRB.conf[:PROMPT_MODE] != :INF_RUBY)
            @io = ReadlineInputMethod.new
          else
            @io = StdioInputMethod.new
          end
        when false
          @io = StdioInputMethod.new
        when true
          if defined?(ReadlineInputMethod)
            @io = ReadlineInputMethod.new
          else
            @io = StdioInputMethod.new
          end
        end

      when String
        @io = FileInputMethod.new(input_method)
        @irb_name = File.basename(input_method)
        @irb_path = input_method
      else
        @io = input_method
      end

      if output_method
        @output_method = output_method
      else
        @output_method = StdioOutputMethod.new
      end

      @verbose = IRB.conf[:VERBOSE]
      @echo = IRB.conf[:ECHO]
      if @echo.nil?
        @echo = true
      end
      @debug_level = IRB.conf[:DEBUG_LEVEL]
    end

    def main
      @workspace.main
    end

    attr_reader :workspace_home
    attr_accessor :workspace
    attr_reader :thread
    attr_accessor :io

    attr_accessor :irb
    attr_accessor :ap_name
    attr_accessor :rc
    attr_accessor :irb_name
    attr_accessor :irb_path
    attr_accessor :use_readline

    attr_reader :prompt_mode
    attr_accessor :prompt_i
    attr_accessor :prompt_s
    attr_accessor :prompt_c
    attr_accessor :prompt_n
    attr_accessor :auto_indent_mode
    attr_accessor :display

    attr_accessor :echo
    attr_accessor :verbose
    attr_reader :debug_level

    attr_reader :input_method
    attr_reader :output_method

    alias use_readline? use_readline
    alias rc? rc
    alias echo? echo

    def verbose?
      if @verbose.nil?
        if defined?(ReadlineInputMethod) && @io.kind_of?(ReadlineInputMethod)
          false
        elsif !STDIN.tty? or @io.kind_of?(FileInputMethod)
          true
        else
          false
        end
      end
    end

    def prompting?
      verbose? || (STDIN.tty? && @io.kind_of?(StdioInputMethod) ||
                (defined?(ReadlineInputMethod) && @io.kind_of?(ReadlineInputMethod)))
    end

    attr_reader :last_value

    def set_last_value(value)
      @last_value = value
      @workspace.evaluate self, "_ = IRB.current_context.last_value"
    end

    def irb_name
      @irb_name ||= "irb" + IRB.job_manager.current_job_id
    end

    def irb_path
      @irb_path ||= "(" + irb_name + ")"
    end

    def prompt_mode=(mode)
      @prompt_mode = mode
      pconf = IRB.conf[:PROMPT][mode]
      @prompt_i = pconf[:PROMPT_I]
      @prompt_s = pconf[:PROMPT_S]
      @prompt_c = pconf[:PROMPT_C]
      @prompt_n = pconf[:PROMPT_N]
      @display = pconf[:RETURN]
      if ai = pconf.include?(:AUTO_INDENT)
        @auto_indent_mode = ai
      else
        @auto_indent_mode = IRB.conf[:AUTO_INDENT]
      end
    end

    def file_input?
      @io.class == FileInputMethod
    end

    def use_readline=(opt)
      @use_readline = opt
    end

    def debug_level=(value)
      @debug_level = value
    end

    def debug?
      @debug_level > 0
    end

    def evaluate(line, line_no)
      @line_no = line_no

      value = @workspace.evaluate(self, line, irb_path, line_no)

      set_last_value(value)

      return unless echo?
      display.show(last_value)
    end

    PROMPTS = {:ltype => :prompt_s, :continue => :prompt_c, :indent => :prompt_n, :normal => :prompt_i}

    def print_verbose(str)
      IRB.puts str if verbose?
    end

    # Formats the prompt according to a format string. Available
    # segments in the format string are:
    #
    # %N:: The irb name (irb)
    # %m:: The main context (main)
    # %M:: The main context, inspected ("main")
    # %l:: The current parsing state (see below)
    # %i:: The amount of current indentation, passed
    #     to format. For instance %03i would produce
    #     "004" if the current indentation level was
    #     4.
    # %n:: The current line number, passed to format
    #     as in "i"
    # %%:: a literal %
    #
    # Parsing states
    # = =begin to =end
    # ' single quoted string
    # " double quoted string (includes %{} etc)
    # : symbol literal created using %s
    # / regular expression (includes %r{} etc)
    # ` shelling out
    # ] array (includes %w{} etc)
    def format_prompt(prompt, ltype, indent, line_no)
      prompt.gsub(/%([0-9]+)?([a-zA-Z])/) do
        case $2
        when "N"
          irb_name
        when "m"
          main.to_s
        when "M"
          main.inspect
        when "l"
          ltype
        when "i"
          format("%#{$1}d", indent)
        when "n"
          format("%#{$1}d", line_no)
        when "%"
          "%"
        end
      end
    end

    alias __exit__ exit
    def exit(ret = 0)
      IRB.irb_exit(ret)
    end

    NOPRINTING_IVARS = ["@last_value"]
    NO_INSPECTING_IVARS = ["@irb", "@io"]
    IDNAME_IVARS = ["@prompt_mode"]

    alias __inspect__ inspect
    def inspect
      array = []
      for ivar in instance_variables.sort{|e1, e2| e1 <=> e2}
        name = ivar.sub(/^@(.*)$/){$1}
        val = instance_eval(ivar)
        case ivar
        when *NOPRINTING_IVARS
          array.push format("conf.%s=%s", name, "...")
        when *NO_INSPECTING_IVARS
          array.push format("conf.%s=%s", name, val.to_s)
        when *IDNAME_IVARS
          array.push format("conf.%s=:%s", name, val.id2name)
        else
          array.push format("conf.%s=%s", name, val.inspect)
        end
      end
      array.join("\n")
    end
  end
end
