module Ladb::OpenCutList::Kuix

  class Motif3d < Entity3d

    attr_accessor :patterns_transformation
    attr_accessor :color
    attr_accessor :line_width, :line_stipple

    def initialize(patterns = [], id = nil)
      super(id)

      @patterns = patterns  # Normalized Array<Array<Kuix::Point2d>>
      @patterns_transformation = Geom::Transformation.new

      @color = nil
      @line_width = 1
      @line_stipple = ''

      @paths = []

    end

    # -- LAYOUT --

    def do_layout(transformation)
      @paths.clear
      @patterns.each do |pattern|
        points = []
        pattern.each do |pattern_point|
          pt = Geom::Point3d.new(pattern_point)
          pt.transform!(@patterns_transformation) unless @patterns_transformation.identity?
          point = Geom::Point3d.new(@bounds.x + pt.x * @bounds.width, @bounds.y + pt.y * @bounds.height, @bounds.z + pt.z * @bounds.depth)
          point.transform!(transformation * @transformation)
          points << point
        end
        @paths << points
      end
      super
    end

    # -- RENDER --

    def paint_content(graphics)
      @paths.each { |points| graphics.draw_line_strip(points, @color, @line_width, @line_stipple) }
      super
    end

  end

  class LineMotif < Motif3d

    attr_reader :start, :end

    def initialize(id = nil)
      super([[

               [ 0, 0, 0 ],
               [ 1, 1, 1 ]

             ]], id)

      @start = Point3d.new
      @end = Point3d.new

    end

    # -- LAYOUT --

    def do_layout(transformation)

      v = @end - @start

      tsx = 1
      tsy = 1
      tsz = 1
      if v.x < 0
        tsx = -1
        v.x = v.x.abs
      end
      if v.y < 0
        tsy = -1
        v.y = v.y.abs
      end
      if v.z < 0
        tsz = -1
        v.z = v.z.abs
      end

      self.patterns_transformation = Geom::Transformation.scaling(tsx, tsy, tsz)
      self.bounds.origin.copy!(@start)
      self.bounds.size.set!(v.x, v.y, v.z)

      super
    end

  end

  class RectangleMotif < Motif3d

    def initialize(id = nil)
      super([[

               [ 0, 0, 0 ],
               [ 1, 0, 0 ],
               [ 1, 1, 0 ],
               [ 0, 1, 0 ],
               [ 0, 0, 0 ],

             ]], id)
    end

  end

  class BoxMotif < Motif3d

    def initialize(id = nil)
      super([
              [
                [ 0, 0, 0 ],
                [ 1, 0, 0 ],
                [ 1, 1, 0 ],
                [ 0, 1, 0 ],
                [ 0, 0, 0 ],
              ],
              [
                [ 0, 0, 1 ],
                [ 1, 0, 1 ],
                [ 1, 1, 1 ],
                [ 0, 1, 1 ],
                [ 0, 0, 1 ],
              ],
              [
                [ 0, 0, 0 ],
                [ 0, 0, 1 ],
              ],
              [
                [ 1, 0, 0 ],
                [ 1, 0, 1 ],
              ],
              [
                [ 0, 1, 0 ],
                [ 0, 1, 1 ],
              ],
              [
                [ 1, 1, 0 ],
                [ 1, 1, 1 ],
              ],
            ], id)
    end

  end

  class ArrowMotif < Motif3d

    def initialize(id = nil)
      super([[

               [  0.05 , 1/3.0 , 0 ],
               [ 1/2.0 , 1/3.0 , 0 ],
               [ 1/2.0 ,  0.05 , 0 ],
               [  0.95 , 1/2.0 , 0 ],
               [ 1/2.0 ,  0.95 , 0 ],
               [ 1/2.0 , 2/3.0 , 0 ],
               [  0.05 , 2/3.0 , 0 ],
               [  0.05 , 1/3.0 , 0 ]

             ]], id)
    end

  end

end