# State Manager

StateManager is a state machine implementation for Ruby that is heavily inspired by the FSM implementation in [Ember.js](http://emberjs.com). Compared to other FSM implementations, it has the following defining characteristics:

* Sub-states are supported (e.g. 'submitted.reviewing').
* State logic can be kept separate from model classes.
* State definitions are modular, underlying each state is a separate class definition.
# Supports integrations. Comes out of the box with an integration with active_record and delayed_job to support automatic delayed transtions.

We believe this is an improvement over existing state machines, but just for good measure, check out [state_machine](https://github.com/pluginaweek/state_machine) and [workflow](https://github.com/geekq/workflow).

## Getting Started

Install the `state_manager` gem. If you are using bundler, add the following to your Gemfile:

```
gem 'state_manager'
```

After the gem is installed, create a file to contain the definition of your state manager, e.g. `app/states/post_states.rb`. Edit this file and define your states:

```ruby
class PostStates < StateManager::Base
  state :unsubmitted do
    event :submit, :transitions_to => 'submitted.awaiting_review'
  end
  state :submitted
    event :reject, :transitions_to => 'rejected'
    state :awaiting_review do
      event :review, :transitions_to => 'submitted.reviewing'
    end
    state :reviewing do
      event :accept, :transitions_to => 'active'
      event :clarify, :transitions_to => 'submitted.clarifying'
    end
    state :clarifying do
      event :review, :transitions_to => 'submitted.reviewing'
    end
  end
  state :active
  state :rejected
end
```

Once your states are defined, you need to extend the `StateManager::Resource` module on your resource class and define a state managed property:

```ruby
class Post
  attr_accessor :state
  extend StateManager::Resource
  state_manager
end
```

The code above infers the existence of `PostStates` class and a `state` property. An alternate states definition and property could be specified as follows:

```ruby
class Post
  attr_accessor :workflow_state
  extend StateManager::Resource
  state_manager :workflow_state, PostStates
end
```

## Helper Methods

Unless otherwise specified with `{:helpers => false}` as the third argument to the `state_manager` macro, helper methods will be added to the resource class. In the above example, some of the methods that will be available are:

```ruby
post = Post.new
post.unsubmitted? # true, the post will initially be in the 'unsubmitted' state
post.can_submit? # true, the 'submit' event is defined on the current state
post.can_review? # false, the 'review' event is not defined on the current state
post.submit! # invokes the submit event
post.submitted_awaiting_review? # true, the post is in the 'submitted.awaiting_review' state
post.submitted? # true, the 'submitted' state is a parent of the current state
```

## Handling Events

Most applications will require special logic to be performed during state transitions. Handlers for events can be defined as follows:

```ruby
class PostStates < StateManager::Base
  state :unsubmitted do
    event :submit, :transitions_to => 'submitted.awaiting_review'
  end
  state :submitted
    event :reject, :transitions_to => 'rejected'
    state :awaiting_review do
      event :review, :transitions_to => 'submitted.reviewing'
    end
    state :reviewing do
      event :accept, :transitions_to => 'active'
      event :clarify, :transitions_to => 'submitted.clarifying'
    end
    state :clarifying do
      event :review, :transitions_to => 'submitted.reviewing'
    end
  end
  state :active
  state :rejected

  # Under the hood, the `state` macro creates a class with the same name as the state. Here we add to the definition of that class.
  class Unsubmitted
    # Defines a handler for the submit event. Events can have arguments
    def submit(reason=nil)
      # Do something, the post is available as either the `resource` or `post` property
    end
  end

  class Submitted
    class AwaitingReview
      # Handles the review event. This will *not* handle the review event for the 'submitted.clarifying' state
      def review
      end
    end

    # Events on parent states are available to their children.
    def reject
    end
  end
end
```

States and events really just correspond to classes and methods of the state manager.

## Under the Hood

Under the hood, the `state_manager` macro makes an instance of a StateManager::Base subclass available through the "#{property}_manager" attribute on the resource. The above examples of helper methods is essentially syntactic sugar on the following:

```ruby
post = Post.new
post.state_manager.in_state?('unsubmitted') # true, the post will initially be in the 'unsubmitted' state
post.state_manager.respond_to_event?('submit') # true, the 'submit' event is defined on the current state
post.state_manager.respond_to_event?('review')? # false, the 'review' event is not defined on the current state
post.state_manager.send_event!('submit') # invokes the submit event
post.state_manager.in_state?('submitted.awaiting_review')? # true, the post is in the 'submitted.awaiting_review' state
post.state_manager.in_state?('submitted')? # true, the 'submitted' state is a parent of the current state
```

Furthermore, only leaf states are valid states for a resource. The state manager can also be explicitly transitioned to a state, however this should normally only be used inside an event handler:

```ruby
post.state_manager.transition_to?('submitted.awaiting_review')? # puts the post is in the 'submitted.awaiting_review' state
post.state_manager.transition_to?('submitted')? # throws a StateManager::InvalidState error, 'submitted' is not a leaf state
```

By default, the initial state will be the first state that was defined. This can be customized by setting the initial state:

```ruby
class PostStates < StateManager::Base
  initial_state :rejected
  ...
end
```

## Callbacks

StateManager has several callbacks that can be hooked into:

```ruby
class PostStates < StateManager::Base
  state :unsubmitted do
    event :submit, :transitions_to => 'submitted.awaiting_review'
  end
  state :submitted

    # Called when the 'submitted' state is being entered
    def enter
    end

    # Called when the 'submitted' state is being exited.
    def exit
    end

    # After it has been entered
    def entered
    end

    # After it has been exited
    def exited
    end

    event :reject, :transitions_to => 'rejected'
    state :awaiting_review do
      event :review, :transitions_to => 'submitted.reviewing'
    end

  ...

  # Called before every transition
  def will_transition(from, to, event)
  end

  # Called after ever transition
  def did_transition(from, to, event)
  end
end
```

In the above example, transitioning between 'submitted.awaiting_review' and 'submitted.reviewing' will not call the the enter/exit callbacks for the 'submitted' state, however it will be called for the children.

## Delayed Job

StateManager comes out of the box with support for [delayed_job](https://github.com/tobi/delayed_job). If delayed_job is available, events can be defined with an `:delay` property which indicates that the event should automatically be called after that delay. For example:

```ruby
class UserStates < StateManager::Base
  state :submitted do
    event :activate, :transitions_to => :active, :delay => 2.days
  end

  state :active
end
```

In this example, the `activate` event will be called by delayed_job automatically after 2 days unless it is called programatically before then.

## Contributing to statemanager
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2012 Gordon Hempton. See LICENSE.txt for
further details.

