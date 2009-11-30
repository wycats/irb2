module IRB
  class ColoredShellString
    COLORS = {
      :"\\/"        => '0;0',
      :nothing      => '0;0',
      :black        => '0;30',
      :red          => '0;31',
      :green        => '0;32',
      :brown        => '0;33',
      :blue         => '0;34',
      :cyan         => '0;36',
      :purple       => '0;35',
      :light_gray   => '0;37',
      :dark_gray    => '1;30',
      :light_red    => '1;31',
      :light_green  => '1;32',
      :yellow       => '1;33',
      :light_blue   => '1;34',
      :light_cyan   => '1;36',
      :light_purple => '1;35',
      :white        => '1;37',
    }

    COLORS_REGEX = Regexp.new("\\[(" + COLORS.keys.join("|") + ")\\]")

    def initialize(str)
      @string = str
    end

    def to_s
      @string.gsub(COLORS_REGEX) { "\033[#{COLORS[$1.to_sym]}m" }
    end
  end
end