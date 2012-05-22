# statemanager

StateManager is a state machine implementation for Ruby that is heavily inspired by the FSM implementation in [Ember.js](http://emberjs.com). Compared to other FSM implementations, it embraces the following features/opinions:

* State logic should not pollute model classes and should be kept separate from model definitions.
* State events should have access to a scope (the current user).
* Sub-states are supported and encouraged.

## Getting Started

Install the `statemanager` gem. If you are using bundler, add the following to your Gemfile:

```
gem 'statemanager'
```

Generate a state manager for a model:

```
rails generate statemanager post
```

This will create a file, `app/states/post_states.rb`. Edit this file and define your states:

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
state_manager.awaiting_review? # returns true
state_manager.submitted_awaiting_review? # returns true
state_manager.submitted_reviewing? # returns false
```

StateManager works by reading and modifying the `state` property of the passed in object. You can specify a different property by setting the `state_property` property on the manager.

## Handling Events

Most applications will require special logic to be performed during state transitions. Handlers can be defined by either passing in a block to the event definitions or by specifying a handler method:

```ruby
state :reviewing do
  event :accept, :transitions_to => 'active' do
    # logic can be defined inline as a block
  end
  event :clarify, :transitions_to => 'submitted.clarifying', :handler => :clarify
event

def clarify
  # alternatively you can specify a handler method, you do not need to specify the handler method name if it is the same as the event
end
```

## Reading State

Rather than having to always create a StateManager instance, shortcut methods are available to read the state of an object. To enable this, include the `Stateful` mixin:

```ruby
class Post
  include Stateful
end
```

This assumes the existence of a `PostStates` class on the load path. Alternatively, a different StateManager class can be specified by setting the `state_manager_class` property. After the mixin has been added, properties are availabe on the model class itself:

```ruby
post.unsubmitted? # returns true
post.submit! # does not work, only read methods are available
```

Because of the contextual nature of events (e.g. requiring the current user), methods which modify the state are not available on the object.

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

