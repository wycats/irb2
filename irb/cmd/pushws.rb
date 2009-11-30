#
#   change-ws.rb - 
#       $Release Version: 0.9.5$
#       $Revision: 11708 $
#       $Date: 2007-02-13 08:01:19 +0900 (Tue, 13 Feb 2007) $
#       by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#   
#

require "irb/cmd/nop.rb"
require "irb/ext/workspaces.rb"

module IRB
  module ExtendCommand
    class Workspaces<Nop
      def execute(*obj)
        workspaces = irb_context.workspaces.map {|w| w.main.inspect} + ["[green]#{irb_context.main.inspect}[/]"]
        IRB.puts "[blue]Workspaces\n----------[/]\n" << workspaces.join("\n")
        IRB::CommandResult
      end
    end

    class PushWorkspace<Workspaces
      def execute(*obj)
        irb_context.push_workspace(*obj)
        super
      end
    end

    class PopWorkspace<Workspaces
      def execute(*obj)
        irb_context.pop_workspace(*obj)
        super
      end
    end
  end
end

