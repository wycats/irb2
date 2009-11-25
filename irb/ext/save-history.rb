#!/usr/local/bin/ruby
#
#   save-history.rb -
#       $Release Version: 0.9.5$
#       $Revision: 11708 $
#       $Date: 2007-02-13 08:01:19 +0900 (Tue, 13 Feb 2007) $
#       by Keiju ISHITSUKAkeiju@ruby-lang.org)
#
# --
#
#
#

require "readline"
require "pathname"

module IRB
  module HistorySavingAbility
    @RCS_ID='-$Id: save-history.rb 11708 2007-02-12 23:01:19Z shyouhei $-'
  end

  class Context
    def init_save_history
      HistorySavingAbility.load_history
    end

    def save_history
      IRB.conf[:SAVE_HISTORY]
    end

    def save_history=(val)
      IRB.conf[:SAVE_HISTORY] = val
      context = IRB.current_context || self
      context.init_save_history if val
    end

    attr_accessor :history_file
  end

  module HistorySavingAbility
    include Readline

    at_exit do
      if (num = IRB.conf[:SAVE_HISTORY].to_i) > 0
        File.open(history_file, 'w') do |f|
          f.puts HISTORY.to_a.last(num).join("\n")
        end
      end
    end

    def self.history_file
      config = IRB.main_context.history_file
      config ? Pathname.new(config) : IRB.rc_file("_history")
    end

    def self.load_history
      hist = history_file
      if hist.exist?
        File.open(hist).each_line {|l| HISTORY << l.chomp }
      end
    end
  end
end
