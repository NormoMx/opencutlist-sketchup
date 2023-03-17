module Ladb::OpenCutList::Kuix

  class Arrow < Lines

    def initialize(id = nil)
      super([
        [     0 , 1/3.0 , 0 ],
        [ 1/2.0 , 1/3.0 , 0 ],
        [ 1/2.0 ,     0 , 0 ],
        [     1 , 1/2.0 , 0 ],
        [ 1/2.0 ,     1 , 0 ],
        [ 1/2.0 , 2/3.0 , 0 ],
        [     0 , 2/3.0 , 0 ]
      ], true, id)
    end

  end

end