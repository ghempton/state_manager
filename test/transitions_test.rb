require 'helper'

class TransitionsTest < Test::Unit::TestCase

  class User
    attr_accessor :state, :notes, :paid, :has_prizes
  end

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

    self.initial_state = :unregistered
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

  def setup
    @user = User.new
    @state = UserStates.new(@user)
  end

  def test_custom_transition
    @user.paid = true
    @state.register!
    assert @state.active_premium?
    @state.transition_to 'unregistered'
    @user.paid = false
    @state.register!
    assert @state.active_default?
  end

  def test_enter_exit
    @state.transition_to('inactive.banned')

    assert_equal 1, @state.find_state('inactive').enter_count
    assert_equal 0, @state.find_state('inactive').exit_count
    assert_equal 1, @state.find_state('inactive.banned').enter_count
    assert_equal 0, @state.find_state('inactive.banned').exit_count

    @state.transition_to(:unregistered)

    assert_equal 1, @state.find_state('inactive').enter_count
    assert_equal 1, @state.find_state('inactive').exit_count
    assert_equal 1, @state.find_state('inactive.banned').enter_count
    assert_equal 1, @state.find_state('inactive.banned').exit_count

    @state.transition_to('inactive.banned')

    assert_equal 2, @state.find_state('inactive').enter_count
    assert_equal 1, @state.find_state('inactive').exit_count
    assert_equal 2, @state.find_state('inactive.banned').enter_count
    assert_equal 1, @state.find_state('inactive.banned').exit_count

    @state.transition_to('inactive.appealing')

    assert_equal 2, @state.find_state('inactive').enter_count
    assert_equal 1, @state.find_state('inactive').exit_count
    assert_equal 2, @state.find_state('inactive.banned').enter_count
    assert_equal 2, @state.find_state('inactive.banned').exit_count
    assert_equal 1, @state.find_state('inactive.appealing').enter_count
    assert_equal 0, @state.find_state('inactive.appealing').exit_count
  end

  def test_event_with_args
    @state.ban!('brogrammer')
    assert_equal 'Banned because: brogrammer', @user.notes
  end

  def test_will_and_did_transition
    @state.ban!

    assert_equal 'unregistered', @state.will_current_state.to_s
    assert_equal 'unregistered', @state.will_from.to_s
    assert_equal 'inactive.banned', @state.will_to.to_s
    assert_equal :ban, @state.will_event

    assert_equal 'inactive.banned', @state.did_current_state.to_s
    assert_equal 'unregistered', @state.did_from.to_s
    assert_equal 'inactive.banned', @state.did_to.to_s
    assert_equal :ban, @state.did_event
  end

end