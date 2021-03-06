#
#   push-ws.rb -
#       $Release Version: 0.9.5$
#       $Revision: 11708 $
#       $Date: 2007-02-13 08:01:19 +0900 (Tue, 13 Feb 2007) $
#       by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#

module IRB
  class Context

    def irb_level
      workspace_stack.size
    end

    def workspaces
      @workspaces ||= []
    end

    def push_workspace(_main = nil)
      unless _main
        IRB.puts "[red]Please specify a workspace to push[/]\n"
        return
      end

      workspaces.push @workspace
      @workspace = WorkSpace.new(_main, @workspace.binding)
      main.extend ExtendCommandBundle
    end

    def pop_workspace
      if workspaces.empty?
        IRB.puts "[red]No workspaces to pop[/]\n\n"
        return
      end

      @workspace = workspaces.pop
    end
  end
end

