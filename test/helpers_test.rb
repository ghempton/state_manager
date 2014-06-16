require 'helper'

class HelpersTest < Minitest::Test

  class ItemStates < StateManager::Base
    state :default do
      event :do_inner, :transitions_to => 'root.outer1.inner'
    end
    state :root do
      state :outer1 do
        event :next, :transitions_to => 'outer2.inner'
        state :inner do
          event :next, :transitions_to => 'inner2'
        end
        state :inner2
      end
      state :outer2 do
        state :inner do
        end
      end
    end
  end

  class Item
    attr_accessor :state
    extend StateManager::Resource
    state_manager
  end

  def setup
    @resource = Item.new
  end

  def test_helpers
    assert @resource.default?
    assert !@resource.root?
    assert !@resource.root_outer1?
    assert !@resource.root_outer1_inner?
    assert @resource.can_do_inner?
    assert !@resource.can_next?

    @resource.do_inner!

    assert @resource.root?
    assert @resource.root_outer1?
    assert @resource.root_outer1_inner?
    assert !@resource.root_outer2_inner?
    assert @resource.can_next?
    
    @resource.next!

    assert @resource.root_outer1_inner2?
    assert @resource.can_next?

    @resource.next!

    assert @resource.root_outer2_inner?
    assert !@resource.can_next?
  end

end
