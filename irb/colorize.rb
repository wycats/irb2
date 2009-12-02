module IRB
  class ColoredShellString
    COLORS = {
      :"\\/"        => '0',
      :nothing      => '0',
      :black        => '30',
      :red          => '31',
      :green        => '32',
      :yellow       => '33',
      :blue         => '34',
      :purple       => '35',
      :cyan         => '36',
      :white        => '37',
      :dark_gray    => '90',
      :light_red    => '91',
      :light_green  => '92',
      :light_yellow => '93',
      :light_blue   => '94',
      :light_purple => '95',
      :light_cyan   => '96',
    }

    COLORS_REGEX = /\[(#{ COLORS.keys.join('|') })\]/

    def initialize(str)
      @string = str
    end

    def to_s
      @string.gsub(COLORS_REGEX) { "\e[#{COLORS[$1.to_sym]}m" }
    end
  end
end