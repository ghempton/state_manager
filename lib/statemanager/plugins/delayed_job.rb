if defined?(Delayed)

  module StateManager
    # Adds support for a :delay property on event definitions. Events with a
    # delay set will be automatically sent after the delay. If the state is
    # changed such that the event is no longer available before the delay is
    # reached, it will be canceled.
    module DelayedJob

      class DelayedEvent < Struct.new(:path, :event, :state_manager)
        def perform
          return unless state_manager.respond_to_event?(event[:name]) &&
            state_manager.in_state?(path)
          state_manager.send_event! event[:name]
        end
      end

      module State

        def delayed_events
          self.class.specification.events.reject{|name,event|!event[:delay]}
        end

        def enter
          delayed_events.each do |name, event|
            delay = event[:delay]
            delayed_event = DelayedEvent.new(path, event, state_manager)
            Delayed::Job.enqueue delayed_event, :run_at => delay.from_now
          end
        end

        def exit
          # TODO: we currently just have logic inside the job itself which
          # skips the event if it is no longer relevant. This is not perfect.
          # Ideally we should cancel events in this method (requiring an
          # efficient way to do this without looping over all events).
        end
      end
    end

    class State
      include DelayedJob::State

      def enter
        super
      end

      def exit
        super
      end
    end
  end

end