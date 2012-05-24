# State Manager

StateManager is a state machine implementation for Ruby that is heavily inspired by the FSM implementation in [Ember.js](http://emberjs.com). Compared to other FSM implementations, it embraces the following features/opinions:

* State logic should not pollute model classes.
* State events should have access to a scope (e.g. the current user).
* Substates are supported and encouraged.

## Getting Started

Install the `statemanager` gem. If you are using bundler, add the following to your Gemfile:

```
gem 'statemanager'
```

After the gem is installed, create a file to contain the definition of your state manager, e.g. `app/states/post_states.rb`. Edit this file and define your states:

```ruby
class PostStates < StateManager::Base
  state :unsubmitted do
    event :submit, :transitions_to => 'submitted.awaiting_review'
  end
  state :submitted
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
end
```

Once your states are defined, you can manipulate them by creating an instance of your StateManager subclass:

```ruby
state_manager = PostStates.create(post, {:scope => current_user})
state_manager.current_state.name # returns 'unsubmitted'
state_manager.submit! # invokes the submit event
state_manager.current_state.name # returns 'submitted.awaiting_review'
state_manager.submitted? # returns true
state_manager.submitted_awaiting_review? # returns true
state_manager.submitted_reviewing? # returns false
```

StateManager works by reading and modifying the `state` property of the passed in object.

## Handling Events

Most applications will require special logic to be performed during state transitions. Handlers can be defined by passing a block to the event definition:

```ruby
state :reviewing do
  event :accept, :transitions_to => 'active' do
    # logic can be defined inline as a block
  end
  event :clarify, :transitions_to => 'submitted.clarifying', :handler => :clarify
event
```

## Model Helpers

Rather than having to always create a StateManager instance, shortcut methods are available to model classes. To enable this, extend the `StateManager::Helpers` module:

```ruby
class Post
  attr_accessor :state
  extend StateManager::Helpers
  stateful :state, PostStates
end
```

This assumes the existence of a `PostStates` class on the load path. After the mixin has been added, properties are availabe on the model class itself:

```ruby
post.unsubmitted? # returns true
post.submit! # sends the submit event
```

The one caveat with this approach is that the state manager is initialized without any context.

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

