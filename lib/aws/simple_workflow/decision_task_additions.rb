require 'aws/simple_workflow/decision_task'

module AWS
  class SimpleWorkflow
    module DecisionTaskAdditions
      def self.included(base)
        base.__send__ :alias_method, :_original_events, :_events
        base.__send__ :protected, :_original_events
      end

      def scheduled_event(event)
        events.to_a[event.attributes.scheduled_event_id - 1]
      end

      def _events &block
        @_events ||= _original_event &block
      end
    end

    DecisionTask.__send__(:include, DecisionTaskAdditions)
  end
end
