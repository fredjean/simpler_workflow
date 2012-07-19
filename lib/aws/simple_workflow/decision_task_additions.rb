require 'aws/simple_workflow/decision_task'

module AWS
  class SimpleWorkflow
    module DecisionTaskAdditions
      def self.extended(inst)
        inst.class.__send__ :alias_method, :_original_events, :events
      end

      def scheduled_event(event)
        events.to_a[event.attributes.scheduled_event_id - 1]
      end

      def events
        @__original_events ||= _original_events
      end

    end

  end
end

