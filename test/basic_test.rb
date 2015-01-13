require 'helper'

class BasicTest < Minitest::Test

  class PostStates < StateManager::Base

    attr_accessor :title
    attr_accessor :around_hit
    
    def initialize(*args)
      super
      @around_hit = 0
    end

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

    class Active
      def entered
        state_manager.title = title
      end
    end
    
    def around_event(name, *args)
      @around_hit += 1
      yield
    end

  end

  class Post

    attr_accessor :state
    extend StateManager::Resource
    state_manager :state

    attr_accessor :title
  end

  class PostWithInitialState
    attr_accessor :state
    extend StateManager::Resource
    state_manager :state, PostStates do
      initial_state 'submitted.awaiting_review'
    end
  end

  class PostWithCustomProperty
    attr_accessor :workflow_state
    extend StateManager::Resource
    state_manager :workflow_state, PostStates
  end

  def setup
    @resource = Post.new
  end

  def test_state_manager_class_initialized
    assert @resource.state_manager.is_a?(PostStates), "state manager should have been initialized"
  end
  
  def test_initial_states
    assert_state 'unsubmitted', "initial state should be set to the default"

    @resource = PostWithInitialState.new

    assert_state 'submitted.awaiting_review', "initial state should be set to specified initial state"

    @resource = Post.new
    @resource.state = 'active'

    assert_state 'active', "initial state should be read from resource"

    @resource = PostWithInitialState.new
    @resource.state = ''

    assert_state 'submitted.awaiting_review', "initial state should be set to specified initial state"
  end

  def test_context
    @resource.state_manager.context[:user] = 'brogrammer'
    assert_equal 'brogrammer', @resource.state_manager.context[:user]
  end

  def test_state_changes
    @resource.state_manager.transition_to 'submitted.clarifying'

    assert_state 'submitted.clarifying', 'state should have transitioned'
    assert_equal @resource.state, 'submitted.clarifying', 'state should have been written'

    @resource.state_manager.transition_to 'reviewing'

    assert_state 'submitted.reviewing', 'state should transition with shorthand sibling name'

    @resource.state_manager.transition_to 'rejected'

    assert_state 'rejected', 'state should have transitioned'
  
    assert_raises StateManager::StateNotFound do
      @resource.state_manager.transition_to 'reviewing'
    end
  end

  def test_events
    @resource.state_manager.send_event! :submit

    assert_equal @resource.state_manager.current_state.path, 'submitted.awaiting_review', 'state should have transitioned'
    assert_equal @resource.state, 'submitted.awaiting_review', 'state should have been written'

    assert_raises StateManager::InvalidEvent do
      @resource.state_manager.send_event! :submit
    end
    assert_equal @resource.state, 'submitted.awaiting_review', 'state should not have changed'

    @resource.state_manager.send_event! :review
  end

  def test_alternate_property
    @resource = PostWithCustomProperty.new
    assert_state 'unsubmitted', @resource.workflow_state_manager

    @resource.workflow_state_manager.send_event! :submit

    assert_equal @resource.workflow_state_manager.current_state.path, 'submitted.awaiting_review', 'state should have transitioned'
    assert_equal @resource.workflow_state, 'submitted.awaiting_review', 'state should have been written'

    assert_raises StateManager::InvalidEvent do
      @resource.workflow_state_manager.send_event! :submit
    end
    assert_equal @resource.workflow_state, 'submitted.awaiting_review', 'state should not have changed'

    @resource.workflow_state_manager.send_event! :review
  end

  def test_can_only_transition_to_leaf
    assert_raises StateManager::InvalidTransition do
      @resource.state_manager.transition_to('submitted')
    end
  end

  def test_transition_to_current_state
    @resource = PostWithInitialState.new
    assert_state 'submitted.awaiting_review'
    @resource.state_manager.transition_to('submitted.awaiting_review')
    assert_state 'submitted.awaiting_review'
  end

  def test_property_proxying
    @resource = Post.new
    @resource.title = 'some title'
    @resource.state_manager.transition_to 'active'
    assert_equal 'some title', @resource.state_manager.title
  end

  def test_around_event
    @resource.state_manager.send_event! :submit
    assert_equal 1, @resource.state_manager.around_hit
  end

end
