require 'helper'

class BasicTest < Test::Unit::TestCase

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

  def setup
    @post = Post.new
    @state = PostStates.new(@post)
  end
  
  def test_initial_states
    assert_equal @state.current_state.path, 'unsubmitted', "initial state should be set to the first state"

    @post = Post.new
    @state = PostStatesWithInitialState.new(@post)

    assert_equal @state.current_state.path, 'submitted.awaiting_review', "initial state should be set to specified initial state"

    @post = Post.new
    @post.state = 'active'
    @state = PostStates.new(@post)

    assert_equal @state.current_state.path, 'active', "initial state should be read from resource"

    @post = Post.new
    @post.state = ''
    @state = PostStatesWithInitialState.new(@post)

    assert_equal 'submitted.awaiting_review', @state.current_state.path, "initial state should be set to specified initial state"
  end

  def test_options
    @state = PostStates.new(@post, {:user => 'brogrammer'})
    assert_equal 'brogrammer', @state.options[:user]
  end

  def test_state_changes
    @state.transition_to 'submitted.clarifying'

    assert_equal @state.current_state.path, 'submitted.clarifying', 'state should have transitioned'
    assert_equal @post.state, 'submitted.clarifying', 'state should have been written'

    @state.transition_to 'reviewing'
    assert_equal @state.current_state.path, 'submitted.reviewing', 'state should transition with shorthand sibling name'

    @state.transition_to 'rejected'
    assert_equal @state.current_state.path, 'rejected', 'state should have transitioned'
  
    assert_raise StateManager::StateNotFound do
      @state.transition_to 'reviewing'
    end
  end

  def test_events
    @state.send_event! :submit

    assert_equal @state.current_state.path, 'submitted.awaiting_review', 'state should have transitioned'
    assert_equal @post.state, 'submitted.awaiting_review', 'state should have been written'

    assert_raise StateManager::InvalidEvent do
      @state.send_event! :submit
    end
    assert_equal @post.state, 'submitted.awaiting_review', 'state should not have changed'

    @state.send_event! :review
  end

end
