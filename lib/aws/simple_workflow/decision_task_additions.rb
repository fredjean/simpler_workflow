require 'aws/simple_workflow/decision_task'

module AWS
  class SimpleWorkflow
    module DecisionTaskAdditions
      def scheduled_event(event)
        events.reverse_order.find { |e| e.id == event.attributes.scheduled_event_id }
      end
    end
  end
end

