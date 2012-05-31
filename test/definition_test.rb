require 'helper'

class DefinitionTest < Test::Unit::TestCase

  class CommentStates < StateManager::Base
    attr_accessor :accept_reason, :reject_reason

    class Submitted < StateManager::State

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

      class Reviewing

        def accept(reason)
          state_manager.accept_reason = reason
        end

      end
    end

    state :unsubmitted do
    end
    state :submitted do
    end
    state :active
    state :rejected

    event :reject

    def accept(reason)
      state_manager.accept_reason = 'bad value'
    end

    def reject(reason)
      self.reject_reason = reason
      transition_to :rejected
    end

    class Unsubmitted

      event :submit, :transitions_to => 'submitted.awaiting_review'

    end

  end

  class Comment
    attr_accessor :state
    extend StateManager::Resource
    state_manager
  end

  def setup
    @resource = Comment.new
  end

  def test_event_in_separate_class_definition
    @resource.submit!
    assert_state 'submitted.awaiting_review'
  end

  def test_states_in_separate_class_definition
    @resource.submit!

    assert_state 'submitted.awaiting_review'

    @resource.review!

    assert_state 'submitted.reviewing'

    @resource.accept!('hipster')

    assert_equal 'hipster', @resource.state_manager.accept_reason
    assert_state 'active'

    @resource.reject!('not a hipster')

    assert_equal 'not a hipster', @resource.state_manager.reject_reason

    assert_state 'rejected'
  end

end
