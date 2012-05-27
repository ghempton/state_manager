require 'helper'
require 'active_record'

class ActiveRecordTest < Test::Unit::TestCase

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

  class Post < ::ActiveRecord::Base
    extend StateManager
    stateful :state
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
        t.integer :id
        t.string :title
        t.string :body
        t.string :state
        t.string :workflow_state
      end
    end

    exec "INSERT INTO posts VALUES(1, NULL, NULL, NULL, NULL)"
    exec "INSERT INTO posts VALUES(2, NULL, NULL, 'unsubmitted', NULL)"
    exec "INSERT INTO posts VALUES(3, NULL, NULL, NULL, 'unsubmitted')"
    exec "INSERT INTO posts VALUES(4, NULL, NULL, 'submitted.reviewing', NULL)"
    exec "INSERT INTO posts VALUES(5, NULL, NULL, 'submitted.bad_state', NULL)"

  end

  def teardown
    ActiveRecord::Base.connection.disconnect!
  end

  def test_set_state_on_initialize
    post = Post.find(1)
    state = PostStates.new(post)

    assert post.changed?
    assert_equal 'unsubmitted', post.state
  end

  def test_persist_initial_state
    post = Post.find(1)
    assert !post.state
    post.save
    assert_equal 'unsubmitted', post.state

    post = Post.find(5)
    assert_equal 'submitted.bad_state', post.state
    post.save
    assert_equal 'unsubmitted', post.state
  end

  def test_update_on_transition
    post = Post.find(3)
    state = PostStates.new(post, :update_on_transition => true)

    state.submit!

    assert !post.changed?
  end

  def test_alternate_state_attribute
    post = Post.find(3)
    state = PostStates.new(post, :state_property => :workflow_state)

    assert_equal 'unsubmitted', state.current_state.path
  end

  def test_initial_state_value
    post = Post.find(4)
    state = PostStates.new(post)

    assert_equal 'submitted.reviewing', state.current_state.path
  end

  def test_invalid_initial_state_value
    post = Post.find(5)
    state = PostStates.new(post)

    assert post.changed?
    assert_equal 'unsubmitted', post.state
  end
end