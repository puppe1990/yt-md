# frozen_string_literal: true

module SampleNs
  class Box
    def plain
      1
    end

    def guarded(flag)
      return :yes if flag

      :no
    end

    def anded(left, right)
      left && right
    end

    def rescued
      JSON.parse("{}")
    rescue JSON::ParserError
      {}
    end

    class Inner
      def inner_plain
        2
      end
    end
  end
end
