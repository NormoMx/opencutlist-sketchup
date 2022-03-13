module Ladb::OpenCutList::Kuix

  class Size

    attr_accessor :width, :height

    def initialize(width = 0, height = 0)
      set(width, height)
    end

    def set(width = 0, height = 0)
      @width = width
      @height = height
    end

    def copy(size)
      set(size.width, size.height)
    end

    # -- Tests --

    def is_empty?
      @width == 0 || @height == 0
    end

    # --

    def to_s
      "#{self.class.name} (width=#{@width}, height=#{@height})"
    end

  end

end