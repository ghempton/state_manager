require 'helper'

class DefinitionTest < Test::Unit::TestCase

  class Comment
    attr_accessor :state
  end

  class CommentStates < StateManager::Base
    attr_accessor :accept_reason, :reject_reason

    class Unsubmitted < StateManager::State

      event :submit, :transitions_to => 'submitted.awaiting_review'

    end

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

  end

  def setup
    @comment = Comment.new
    @state = CommentStates.new(@comment)
  end

  def test_event_in_separate_class_definition
    @state.submit!
    assert @state.in_state?('submitted.awaiting_review')
  end

  def test_states_in_separate_class_definition
    @state.submit!
    assert @state.in_state?('submitted.awaiting_review')
    @state.review!
    assert @state.in_state?('submitted.reviewing')
    @state.accept!('hipster')
    assert_equal 'hipster', @state.accept_reason 
    assert @state.in_state?('active')
    @state.reject!('not a hipster')
    assert_equal 'not a hipster', @state.reject_reason
    assert @state.in_state?('rejected')
  end

end
