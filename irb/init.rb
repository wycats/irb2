#
#   irb/init.rb - irb initialize module
#       $Release Version: 0.9.5$
#       $Revision: 11708 $
#       $Date: 2007-02-13 08:01:19 +0900 (Tue, 13 Feb 2007) $
#       by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#

require "pathname"

module IRB

  # initialize config
  def IRB.setup(ap_path)
    IRB.init_config(ap_path)
    IRB.init_error
    IRB.parse_opts
    IRB.run_config

    unless conf[:PROMPT][conf[:PROMPT_MODE]]
      IRB.fail(UndefinedPromptMode, conf[:PROMPT_MODE])
    end
  end

  class AbstractDisplay
    attr_accessor :io

    def initialize(io = STDOUT)
      @io = io
    end

    def show(result)
      raise NotImplementedError
    end

  private
    def output(string, result)
      @io.puts string
    end

    def format(result)
      return "" if IRB::CommandResult === result
      result.inspect
    end
  end

  module EliminateCommands
    def output(str, result)
      return if IRB::CommandResult === result
      super
    end
  end

  class SimpleDisplay < AbstractDisplay
    include EliminateCommands

    def show(result)
      output format(result), result
    end
  end

  class ArrowDisplay < SimpleDisplay
    include EliminateCommands

    def show(result)
      output "#{IRB.job_manager.current_job_id}   => #{format(result)}", result
    end
  end

  class XMPDisplay < ArrowDisplay
    include EliminateCommands

    def show(result)
      output "   ==> #{format(result)}", result
    end
  end

  # conf[ default setting
  def IRB.init_config(ap_path)
    # class instance variables
    @TRACER_INITIALIZED = false

    # default configurations
    unless ap_path and conf[:AP_NAME]
      ap_path = File.join(File.dirname(File.dirname(__FILE__)), "irb.rb")
    end
    conf[:AP_NAME] = File::basename(ap_path, ".rb")

    conf[:IRB_NAME] = "irb"
    conf[:IRB_LIB_PATH] = File.dirname(__FILE__)

    conf[:RC] = true

    conf[:MATH_MODE] = false
    conf[:USE_READLINE] = false unless defined?(ReadlineInputMethod)
    conf[:INSPECT_MODE] = nil
    conf[:USE_TRACER] = false
    conf[:USE_LOADER] = false
    conf[:ECHO] = nil
    conf[:VERBOSE] = nil

    conf[:EVAL_HISTORY] = nil
    conf[:SAVE_HISTORY] = nil

    conf[:PROMPT] = {
      :NULL => {
        :PROMPT_I => nil,
        :PROMPT_N => nil,
        :PROMPT_S => nil,
        :PROMPT_C => nil,
        :RETURN => SimpleDisplay.new
      },
      :DEFAULT => {
        :PROMPT_I => "%N(%m):%03n:%i> ",
        :PROMPT_N => "%N(%m):%03n:%i> ",
        :PROMPT_S => "%N(%m):%03n:%i%l ",
        :PROMPT_C => "%N(%m):%03n:%i* ",
        :RETURN => ArrowDisplay.new
      },
      :CLASSIC => {
        :PROMPT_I => "%N(%m):%03n:%i> ",
        :PROMPT_N => "%N(%m):%03n:%i> ",
        :PROMPT_S => "%N(%m):%03n:%i%l ",
        :PROMPT_C => "%N(%m):%03n:%i* ",
        :RETURN => SimpleDisplay.new
      },
      :SIMPLE => {
        :PROMPT_I => ">> ",
        :PROMPT_N => ">> ",
        :PROMPT_S => nil,
        :PROMPT_C => "?> ",
        :RETURN => ArrowDisplay.new
      },
      :INF_RUBY => {
        :PROMPT_I => "%N(%m):%03n:%i> ",
        :PROMPT_N => nil,
        :PROMPT_S => nil,
        :PROMPT_C => nil,
        :RETURN => SimpleDisplay.new,
        :AUTO_INDENT => true
      },
      :XMP => {
        :PROMPT_I => nil,
        :PROMPT_N => nil,
        :PROMPT_S => nil,
        :PROMPT_C => nil,
        :RETURN => XMPDisplay.new
      }
    }

    conf[:PROMPT_MODE] = (STDIN.tty? ? :DEFAULT : :NULL)
    conf[:AUTO_INDENT] = false

    conf[:CONTEXT_MODE] = 3 # use binding in function on TOPLEVEL_BINDING
    conf[:SINGLE_IRB] = false

#    conf[:LC_MESSAGES] = "en"
    conf[:LC_MESSAGES] = Locale.new

    conf[:DEBUG_LEVEL] = 1
  end

  def IRB.init_error
    conf[:LC_MESSAGES].load("irb/error.rb")
  end

  FEATURE_IOPT_CHANGE_VERSION = "1.9.0"

  # option analyzing
  def IRB.parse_opts
    load_path = []
    while opt = ARGV.shift
      case opt
      when "-f"
        conf[:RC] = false
      when "-m"
        conf[:MATH_MODE] = true
      when "-d"
        $DEBUG = true
      when /^-r(.+)?/
        opt = $1 || ARGV.shift
        conf[:LOAD_MODULES].push opt if opt
      when /^-I(.+)?/
        opt = $1 || ARGV.shift
        load_path.concat(opt.split(File::PATH_SEPARATOR)) if opt
      when /^-K(.)/
        $KCODE = $1
      when "--readline"
        conf[:USE_READLINE] = true
      when "--noreadline"
        conf[:USE_READLINE] = false
      when "--echo"
        conf[:ECHO] = true
      when "--noecho"
        conf[:ECHO] = false
      when "--verbose"
        conf[:VERBOSE] = true
      when "--noverbose"
        conf[:VERBOSE] = false
      when "--prompt-mode", "--prompt"
        prompt_mode = ARGV.shift.upcase.tr("-", "_").intern
        conf[:PROMPT_MODE] = prompt_mode
      when "--noprompt"
        conf[:PROMPT_MODE] = :NULL
      when "--inf-ruby-mode"
        conf[:PROMPT_MODE] = :INF_RUBY
      when "--sample-book-mode", "--simple-prompt"
        conf[:PROMPT_MODE] = :SIMPLE
      when "--tracer"
        conf[:USE_TRACER] = true
      when "--context-mode"
        conf[:CONTEXT_MODE] = ARGV.shift.to_i
      when "--single-irb"
        conf[:SINGLE_IRB] = true
      when "--irb_debug"
        conf[:DEBUG_LEVEL] = ARGV.shift.to_i
      when "-v", "--version"
        print IRB.version, "\n"
        exit 0
      when "-h", "--help"
        require "irb/help"
        IRB.print_usage
        exit 0
      when /^-/
        IRB.fail UnrecognizedSwitch, opt
      else
        conf[:SCRIPT] = opt
        $0 = opt
        break
      end
    end
    if RUBY_VERSION >= FEATURE_IOPT_CHANGE_VERSION
      load_path.collect! do |path|
        /\A\.\// =~ path ? path : File.expand_path(path)
      end
    end
    $LOAD_PATH.unshift(*load_path)
  end

  # running config
  def IRB.run_config
    if conf[:RC]
      begin
        load rc_file
      rescue LoadError, Errno::ENOENT
      rescue
        print "load error: #{rc_file}\n"
        print $!.class, ": ", $!, "\n"
        for err in $@[0, $@.size - 2]
          print "\t", err, "\n"
        end
      end
    end
  end

  def IRB.rc_file(ext = "rc")
    possible = [".irb#{ext}", "_irb#{ext}", "$irb#{ext}", "irb.#{ext}"]

    base = Pathname.new(ENV["HOME"] || Dir.pwd)

    possible.each do |file|
      check = base.join(file)
      return check if check.exist?
    end

    return base.join(".irb#{ext}")
  end

end
