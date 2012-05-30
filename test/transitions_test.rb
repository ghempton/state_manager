require 'helper'

class TransitionsTest < Test::Unit::TestCase

  class UserStates < StateManager::Base
    module TrackEnterExitCounts
      attr_reader :enter_count
      attr_reader :exit_count

      def initialize(*args)
        super(*args)
        @enter_count = 0
        @exit_count = 0
      end

      def enter
        @enter_count += 1
      end

      def exit
        @exit_count += 1
      end
    end

    attr_reader :enter_counts, :exit_counts

    def initialize(target, options={})
      super(target, options)
      @enter_counts = {}
      @exit_counts = {}
    end

    def inc_enter_count(state)
      enter_counts[state] = 0 unless enter_counts[state]
      enter_counts[state] = enter_counts[state] + 1
    end

    def inc_exit_count(state)
      exit_counts[state] = 0 unless exit_counts[state]
      exit_counts[state] = exit_counts[state] + 1
    end

    initial_state :unregistered
    event :ban, :transitions_to => 'inactive.banned' do |reason=nil|
      user.notes = "Banned because: #{reason}"
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
    state :inactive do
      include TrackEnterExitCounts

      state :banned do
        include TrackEnterExitCounts

        event :appeal, :transitions_to => :appealing
      end

      state :appealing do
        include TrackEnterExitCounts
      end

      event :unban, :transitions_to => 'active.default'
    end

    attr_accessor :will_current_state, :will_from, :will_to, :will_event
    def will_transition(from, to, event)
      self.will_current_state = current_state
      self.will_from = from
      self.will_to = to
      self.will_event = event
    end

    attr_accessor :did_current_state, :did_from, :did_to, :did_event
    def did_transition(from, to, event)
      self.did_current_state = current_state
      self.did_from = from
      self.did_to = to
      self.did_event = event
    end

  end

  class User
    attr_accessor :state, :notes, :paid, :has_prizes
    extend StateManager::Resource
    state_manager
  end

  def setup
    @resource = User.new
  end

  def test_custom_transition
    @resource.paid = true
    @resource.register!

    assert @resource.active_premium?

    @resource.state_manager.transition_to 'unregistered'
    @resource.paid = false
    @resource.register!

    assert @resource.active_default?
  end

  def test_enter_exit
    @resource.state_manager.transition_to('inactive.banned')

    assert_equal 1, @resource.state_manager.find_state('inactive').enter_count
    assert_equal 0, @resource.state_manager.find_state('inactive').exit_count
    assert_equal 1, @resource.state_manager.find_state('inactive.banned').enter_count
    assert_equal 0, @resource.state_manager.find_state('inactive.banned').exit_count

    @resource.state_manager.transition_to(:unregistered)

    assert_equal 1, @resource.state_manager.find_state('inactive').enter_count
    assert_equal 1, @resource.state_manager.find_state('inactive').exit_count
    assert_equal 1, @resource.state_manager.find_state('inactive.banned').enter_count
    assert_equal 1, @resource.state_manager.find_state('inactive.banned').exit_count

    @resource.state_manager.transition_to('inactive.banned')

    assert_equal 2, @resource.state_manager.find_state('inactive').enter_count
    assert_equal 1, @resource.state_manager.find_state('inactive').exit_count
    assert_equal 2, @resource.state_manager.find_state('inactive.banned').enter_count
    assert_equal 1, @resource.state_manager.find_state('inactive.banned').exit_count

    @resource.state_manager.transition_to('inactive.appealing')

    assert_equal 2, @resource.state_manager.find_state('inactive').enter_count
    assert_equal 1, @resource.state_manager.find_state('inactive').exit_count
    assert_equal 2, @resource.state_manager.find_state('inactive.banned').enter_count
    assert_equal 2, @resource.state_manager.find_state('inactive.banned').exit_count
    assert_equal 1, @resource.state_manager.find_state('inactive.appealing').enter_count
    assert_equal 0, @resource.state_manager.find_state('inactive.appealing').exit_count
  end

  def test_event_with_args
    @resource.ban!('brogrammer')
    assert_equal 'Banned because: brogrammer', @resource.notes
  end

  def test_will_and_did_transition
    @resource.ban!

    assert_equal 'unregistered', @resource.state_manager.will_current_state.to_s
    assert_equal 'unregistered', @resource.state_manager.will_from.to_s
    assert_equal 'inactive.banned', @resource.state_manager.will_to.to_s
    assert_equal :ban, @resource.state_manager.will_event

    assert_equal 'inactive.banned', @resource.state_manager.did_current_state.to_s
    assert_equal 'unregistered', @resource.state_manager.did_from.to_s
    assert_equal 'inactive.banned', @resource.state_manager.did_to.to_s
    assert_equal :ban, @resource.state_manager.did_event
  end

end