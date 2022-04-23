module Ladb::OpenCutList
module Dentaku
  module AST
    class CaseWhen < Operation
      attr_reader :node

      def initialize(node)
        @node = node
      end

      def value(context = {})
        @node.value(context)
      end

      def dependencies(context = {})
        @node.dependencies(context)
      end

      def self.arity
        1
      end

      def self.min_param_count
        1
      end

      def self.max_param_count
        1
      end

      def accept(visitor)
        visitor.visit_when(self)
      end

      def to_s
        'WHEN'
      end
    end
  end
end
end
