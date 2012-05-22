require 'helper'

class Post
  attr_accessor :state
end

class PostStates < StateManager::Base
  state :unsubmitted do
    event :submit, :transitions_to => 'submitted.awaiting_review'
  end
  state :submitted do
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

class PostStatesWithInitialState < PostStates
  self.initial_state = 'submitted.awaiting_review'
end

class BasicTest < Test::Unit::TestCase

  def setup
    @post = Post.new
    @post_states = PostStates.new(@post)
  end
  
  def test_initial_states
    assert_equal @post_states.current_state.path, 'unsubmitted', "initial state should be set to the first state"

    sm_initial = PostStatesWithInitialState.new(@post)

    assert_equal sm_initial.current_state.path, 'submitted.awaiting_review', "initial state should be set to specified initial state"

    @post.state = 'active'
    @post_states = PostStates.new(@post)

    assert_equal @post_states.current_state.path, 'active', "initial state should be read from target" 
  end

  def test_options
    @post_states = PostStates.new(@post, {:user => 'brogrammer'})
    assert_equal 'brogrammer', @post_states.options[:user]
  end

  def test_state_changes
    @post_states.transition_to 'submitted.clarifying'

    assert_equal @post_states.current_state.path, 'submitted.clarifying', 'state should have transitioned'
    assert_equal @post.state, 'submitted.clarifying', 'state should have been written'

    @post_states.transition_to 'reviewing'
    assert_equal @post_states.current_state.path, 'submitted.reviewing', 'state should transition with shorthand sibling name'

    @post_states.transition_to 'rejected'
    assert_equal @post_states.current_state.path, 'rejected', 'state should have transitioned'
  
    assert_raise StateManager::StateNotFound do
      @post_states.transition_to 'reviewing'
    end
  end

  def test_events
    @post_states.send_event! :submit

    assert_equal @post_states.current_state.path, 'submitted.awaiting_review', 'state should have transitioned'
    assert_equal @post.state, 'submitted.awaiting_review', 'state should have been written'

    assert_raise StateManager::InvalidEvent do
      @post_states.send_event! :submit
    end
    assert_equal @post.state, 'submitted.awaiting_review', 'state should not have changed'

    @post_states.send_event! :review
  end

end
