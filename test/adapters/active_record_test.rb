require 'helper'

class ActiveRecordTest < Minitest::Test

  class PostStates < StateManager::Base
    attr_accessor :before_callbacks_called
    attr_accessor :after_callbacks_called

    state :unsubmitted do
      event :submit, :transitions_to => 'submitted.awaiting_review'
      event :activate, :transitions_to => 'active'
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
    state :mutated
    
    attr_accessor :unsubmitted_entered_count
    attr_accessor :unsubmitted_enter_committed_count
    attr_accessor :unsubmitted_exit_committed_count

    attr_accessor :active_entered_count
    attr_accessor :active_enter_committed_count
    attr_accessor :active_exit_committed_count

    def initialize(*args)
      super
      @unsubmitted_entered_count = 0
      @unsubmitted_enter_committed_count = 0
      @unsubmitted_exit_committed_count = 0
      @active_entered_count = 0
      @active_enter_committed_count = 0
      @active_exit_committed_count =0
    end

    def will_transition(*args)
      self.before_callbacks_called = true
    end

    def did_transition(*args)
      self.after_callbacks_called = true
    end
    
    class Unsubmitted
      
      def entered
        state_manager.unsubmitted_entered_count += 1
      end

      def enter_committed
        state_manager.unsubmitted_enter_committed_count += 1
      end

      def exit_committed
        state_manager.unsubmitted_exit_committed_count += 1
      end
      
    end
    
    class Active
      
      def entered
        state_manager.active_entered_count += 1
      end

      def enter_committed
        state_manager.active_enter_committed_count += 1
      end

      def exit_committed
        state_manager.active_exit_committed_count += 1
      end
      
    end

    class Mutated

      def entered
        self.title = 'mutant'
        save
      end

    end
    
  end

  class Post < ActiveRecord::Base
    extend StateManager::Resource
    state_manager
  end

  def exec(sql)
    ActiveRecord::Base.connection.execute sql
  end

  def setup
    ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
      :database  => ":memory:" #"tmp/test"
    )

    ActiveRecord::Schema.define do
      create_table :posts do |t|
        t.string :title
        t.string :body
        t.string :state
      end
    end

    exec "INSERT INTO posts VALUES(1, NULL, NULL, NULL)"
    exec "INSERT INTO posts VALUES(2, NULL, NULL, 'unsubmitted')"
    exec "INSERT INTO posts VALUES(3, NULL, NULL, 'submitted.reviewing')"
    exec "INSERT INTO posts VALUES(4, NULL, NULL, 'submitted.bad_state')"

    @resource = nil
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
    ActiveRecord::Base.connection.disconnect!
  end

  def test_adapter_included
    @resource = Post.find(1)
    assert @resource.is_a?(StateManager::Adapters::ActiveRecord::ResourceMethods)
    assert @resource.state_manager.is_a?(StateManager::Adapters::ActiveRecord::ManagerMethods)
  end

  def test_persist_initial_state
    @resource = Post.find(1)
    assert_state 'unsubmitted'
    assert !@resource.state_manager.before_callbacks_called
    assert !@resource.state_manager.after_callbacks_called
    assert @resource.changed?, "state should not have been persisted"
    @resource.transaction do
      @resource.save
      assert @resource.state_manager.before_callbacks_called
      assert @resource.state_manager.after_callbacks_called
    end
  end

  def test_initial_state_value
    @resource = Post.find(3)
    assert_state 'submitted.reviewing'
  end

  def test_validate_nil_state
    @resource = Post.find(1)
    assert !@resource.state
    @resource.save
    assert_state 'unsubmitted'
  end

  def test_validate_invalid_state
    @resource = Post.find(4)
    assert_equal 'submitted.bad_state', @resource.state
    @resource.save
    assert_state 'unsubmitted'
  end

  def test_new_record
    @resource = Post.new
    assert_state 'unsubmitted'
    assert @resource.new_record?, 'record should not have been persisted'
    @resource.save
    @resource.submit!
    assert_state 'submitted.awaiting_review'
    assert !@resource.new_record?, 'record should be persisted'
  end

  def test_scopes
    exec "INSERT INTO posts VALUES(5, NULL, NULL, 'submitted.reviewing')"
    exec "INSERT INTO posts VALUES(6, NULL, NULL, 'submitted.reviewing')"
    exec "INSERT INTO posts VALUES(7, NULL, NULL, 'submitted.reviewing')"
    exec "INSERT INTO posts VALUES(8, NULL, NULL, 'submitted.reviewing')"
    exec "INSERT INTO posts VALUES(9, NULL, NULL, 'submitted.clarifying')"
    exec "INSERT INTO posts VALUES(10, NULL, NULL, 'submitted.clarifying')"

    exec "INSERT INTO posts VALUES(11, NULL, NULL, 'active')"
    exec "INSERT INTO posts VALUES(12, NULL, NULL, 'active')"
    exec "INSERT INTO posts VALUES(13, NULL, NULL, 'active')"
    exec "INSERT INTO posts VALUES(14, NULL, NULL, 'active')"

    # +1 from setup
    assert_equal 1, Post.unsubmitted.count
    # +2 from setup
    assert_equal 8, Post.submitted.count
    assert_equal 4, Post.active.count
    assert_equal 0, Post.rejected.count
  end

  def test_multiple_transitions
    @resource = Post.find(2)
    @resource.submit!
    assert_state 'submitted.awaiting_review'
    @resource.review!
    assert_state 'submitted.reviewing'
  end

  def test_dirty_transition
    @resource = Post.find(2)
    @resource.state_manager.send_event :submit
    assert_state 'submitted.awaiting_review'
    assert_raises(StateManager::Adapters::ActiveRecord::DirtyTransition) do
      @resource.state_manager.send_event :review
    end
  end
  
  def test_commit_callbacks
    @resource = Post.find(1)
    assert_state 'unsubmitted'
    assert !@resource.state_manager.before_callbacks_called
    assert !@resource.state_manager.after_callbacks_called
    assert @resource.changed?, "state should not have been persisted"
    @resource.transaction do
      @resource.save!
      assert @resource.state_manager.before_callbacks_called
      assert @resource.state_manager.after_callbacks_called
      assert_equal @resource.state_manager.unsubmitted_enter_committed_count, 0
      @resource.activate!
      assert_equal @resource.state_manager.unsubmitted_exit_committed_count, 0
      assert_equal @resource.state_manager.active_enter_committed_count, 0
    end
    assert_equal 1, @resource.state_manager.unsubmitted_enter_committed_count
    assert_equal 1, @resource.state_manager.unsubmitted_exit_committed_count
    assert_equal 1, @resource.state_manager.active_enter_committed_count
    @resource.title = 'blah'
    @resource.save!
    assert_equal 1, @resource.state_manager.unsubmitted_enter_committed_count
    assert_equal 1, @resource.state_manager.unsubmitted_exit_committed_count
    assert_equal 1, @resource.state_manager.active_enter_committed_count
  end
  
  def test_commit_callbacks_on_create
    Post.transaction do
      @resource = Post.new
      assert !@resource.state_manager.after_callbacks_called
      @resource.save
      assert @resource.state_manager.after_callbacks_called
      assert_equal 1, @resource.state_manager.unsubmitted_entered_count
      assert_equal 0, @resource.state_manager.unsubmitted_enter_committed_count
    end
    assert_equal 1, @resource.state_manager.unsubmitted_enter_committed_count
  end
  
  def test_commit_callbacks_on_different_initial_state
    Post.transaction do
      @resource = Post.new(:state => 'active')
      assert !@resource.state_manager.after_callbacks_called
      @resource.save
      assert @resource.state_manager.after_callbacks_called
    end
    assert_equal @resource.state_manager.unsubmitted_entered_count, 0
    assert_equal @resource.state_manager.active_entered_count, 1
    assert_equal @resource.state_manager.active_enter_committed_count, 1
  end

  def test_save_in_entered_callback
    @resource = Post.new(:state => 'mutated')
    @resource.save
    assert_equal 'mutant', @resource.title
  end
end
