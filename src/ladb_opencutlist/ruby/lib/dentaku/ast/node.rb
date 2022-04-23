module Ladb::OpenCutList
module Dentaku
  module AST
    class Node
      def self.precedence
        0
      end

      def self.arity
        nil
      end

      def self.peek(*)
      end

      def dependencies(context = {})
        []
      end

      def type
        nil
      end

      def name
        self.class.name.to_s.split("::").last.upcase
      end
    end
  end
end
end
