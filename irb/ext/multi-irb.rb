#
#   irb/multi-irb.rb - multiple irb module
#       $Release Version: 0.9.5$
#       $Revision: 11708 $
#       $Date: 2007-02-13 08:01:19 +0900 (Tue, 13 Feb 2007) $
#       by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#
IRB.fail CantShiftToMultiIrbMode unless defined?(Thread)
require "thread"

module IRB
  # job management class
  class JobManager
    @RCS_ID='-$Id: multi-irb.rb 11708 2007-02-12 23:01:19Z shyouhei $-'

    def initialize
      # @jobs = [[thread, irb],...]
      @jobs = []
      @current_job = nil
    end

    attr_accessor :current_job

    def current_job_id
      job = @jobs.find {|t,j| j == @current_job }
      return "" if job[0] == Thread.main
      "#" + @jobs.index(job).to_s
    end

    def display_jobs
      IRB.puts "Jobs:"
      IRB.p self
    end

    def n_jobs
      @jobs.size
    end

    def thread(key)
      search(key)[0]
    end

    def irb(key)
      search(key)[1]
    end

    def insert(irb)
      @jobs.push [Thread.current, irb]
    end

    def switch(key)
      th, irb = search(key)

      unless th
        IRB.puts "[red]Invalid job[/] ([blue]#{key}[/])"
        IRB.puts
        IRB.job_manager.display_jobs
        return
      end

      unless th.alive?
        IRB.puts "[red]That job is already dead[/]"
      end

      if th == Thread.current
        IRB.puts "[red]You are already on job #{key}[/]"
        return
      end

      @current_job = irb
      th.run
      switch_away
    end

    def switch_away
      IRB.pause
      throw :irb_exit if $die == Thread.current
      @current_job = irb(Thread.current)
    end

    def kill(*keys)
      for key in keys
        th, irb = search(key)

        delete(irb)

        IRB.fail IrbAlreadyDead unless th.alive?
        th.kill
      end
      IRB::CommandResult
    end

    def search(key)
      case key
      when Integer
        @jobs[key]
      when Irb
        @jobs.find{|k, v| v.equal?(key)}
      when Thread
        @jobs.assoc(key)
      else
        assoc = @jobs.find{|k, v| v.context.main.equal?(key)}
        IRB.fail NoSuchJob, key if assoc.nil?
        assoc
      end
    end

    def delete(key)
      case key
      when Integer
        IRB.fail NoSuchJob, key unless @jobs[key]
        @jobs[key] = nil
      else
        result = @jobs.each_with_index do |job, idx|
          if job and job[1] == key
            @jobs[idx] = nil
            break :EXISTS
          end
        end
        IRB.fail NoSuchJob, key unless result == :EXISTS
      end
      @jobs.pop until @jobs.last || @jobs.empty?
    end

    def inspect
      ary = []
      @jobs.each_index do |i|
        th, irb = @jobs[i]
        next if th.nil?

        status = if th.alive?
          th.stop? ? "white" : "green"
        else
          "red"
        end

        locals = irb.context.workspace.evaluate(nil, "local_variables") - ["_"]
        locals = locals.empty? ? "none" : locals.join(", ")

        str = format("[blue]#%d[/] [#{status}]%s[/] | locals: %s",
                     i, irb.context.main, locals)

        ary.push str
      end
      ary.join("\n")
    end
  end

  def self.job_manager
    @job_manager ||= JobManager.new
  end

  def self.current_context
    job_manager.irb(Thread.current).context
  end

  # invoke multi-irb
  def IRB.irb(file = nil, *main)
    workspace = WorkSpace.new(*main)
    parent_thread = Thread.current
    Thread.start do
      begin
        irb = Irb.new(workspace, file)
      rescue
        print "Subirb can't start with context(self): ", workspace.main.inspect, "\n"
        print "return to main irb\n"
        Thread.pass
        Thread.main.wakeup
        Thread.exit
      end

      job_manager.insert(irb)
      job_manager.current_job = irb

      begin
        system_exit = false
        STDOUT.flush

        catch(:irb_exit) do
          irb.eval_input
        end
      rescue SystemExit
        system_exit = true
        raise
      ensure
        unless system_exit
          if parent_thread.alive?
            thread = parent_thread
          else
            thread = job_manager.thread(0)
          end

          job_manager.delete(irb)
          job_manager.current_job = job_manager.irb(thread)
          thread.run
        end
      end
    end

    job_manager.switch_away
  end

  job_manager.insert(main_context.irb)
  job_manager.current_job = main_context.irb

  class Irb
    def signal_handle
      case @signal_status
      when :IN_INPUT
        print "^C\n"
        IRB.job_manager.thread(self).raise RubyLex::TerminateLineInput
      when :IN_EVAL
        IRB.irb_abort(self)
      when :IN_LOAD
        IRB.irb_abort(self, LoadAbort)
      when :IN_IRB
        # ignore
      else
        # ignore other cases as well
      end
    end
  end

  trap("SIGINT") do
    job_manager.current_job.signal_handle
    IRB.pause
  end

end
