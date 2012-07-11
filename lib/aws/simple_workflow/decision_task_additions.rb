require 'aws/simple_workflow/decision_task'

module AWS
  class SimpleWorkflow
    module DecisionTaskAdditions
      def scheduled_event(event)
        events.to_a[event.attributes.scheduled_event_id - 1]
      end
    end

    DecisionTask.__send__(:include, DecisionTaskAdditions)
  end
end
