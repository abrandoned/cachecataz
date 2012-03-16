class MockModel
  include Cachecataz
  
  cache_scope :empty
  cache_scope :test, :id
  cache_scope :user, :user_id
  cache_scope :multi, [:id, :user_id]

  def initialize
    @id = "1"
    @user_id = "2"
    @assoc_id = "3"
  end
  
  def id
    @id
  end
  
  def user_id
    @user_id
  end
  
  def assoc_id
    @assoc_id
  end
  
  def attributes
    {:user_id => @user_id, :id => @id, "assoc_id" => @assoc_id, "extra" => "attributes", "not" => "important", :but => :present}
  end
end
