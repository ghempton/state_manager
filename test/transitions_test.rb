require 'helper'

class User
  attr_accessor :state, :notes, :paid, :has_prizes
end

class UserStates < StateManager::Base
  attr_accessor :enter_count, :exit_count

  def initialize(target, options={})
    super(target, options)
    self.enter_count = 0
    self.exit_count = 0
  end

  self.initial_state = :unregistered
  event :ban, :transitions_to => :banned do |reason|
    resource.notes = "Banned because: #{reason}"
  end
  state :unregistered do
    event :register do
      if resource.paid
        transition_to 'active.premium'
      else
        transition_to 'active.default'
      end
    end
  end
  state :active do
    event :ping
    state :default do
    end
    state :premium do
      event :ping do
        resource.has_prizes = true
      end
    end
  end
  state :banned do
    def enter(manager)
      manager.enter_count += 1
    end

    def exit(manager)
      manager.exit_count += 1
    end

    event :unban, :transitions_to => 'active.default'
  end

  attr_accessor :will_current_state, :will_from, :will_to
  def will_transition(from, to)
    self.will_current_state = current_state
    self.will_from = from
    self.will_to = to
  end

  attr_accessor :did_current_state, :did_from, :did_to
  def did_transition(from, to)
    self.did_current_state = current_state
    self.did_from = from
    self.did_to = to
  end

end

class TransitionsTest < Test::Unit::TestCase

  def setup
    @user = User.new
    @user_states = UserStates.new(@user)
  end

  def test_custom_transition
    @user.paid = true
    @user_states.register!
    assert @user_states.active_premium?
    @user_states.transition_to 'unregistered'
    @user.paid = false
    @user_states.register!
    assert @user_states.active_default?
  end

  def test_enter_exit
    assert_equal 0, @user_states.enter_count
    assert_equal 0, @user_states.exit_count

    @user_states.transition_to(:banned)

    assert_equal 1, @user_states.enter_count
    assert_equal 0, @user_states.exit_count

    @user_states.transition_to(:unregistered)

    assert_equal 1, @user_states.enter_count
    assert_equal 1, @user_states.exit_count

    @user_states.transition_to(:banned)

    assert_equal 2, @user_states.enter_count
    assert_equal 1, @user_states.exit_count
  end

  def test_event_with_args
    @user_states.ban!('brogrammer')
    assert_equal 'Banned because: brogrammer', @user.notes
  end

  def test_handlers
    @user_states.transition_to(:banned)

    assert_equal 'unregistered', @user_states.will_current_state.to_s
    assert_equal 'unregistered', @user_states.will_from.to_s
    assert_equal 'banned', @user_states.will_to.to_s

    assert_equal 'banned', @user_states.did_current_state.to_s
    assert_equal 'unregistered', @user_states.will_from.to_s
    assert_equal 'banned', @user_states.will_to.to_s
  end

end