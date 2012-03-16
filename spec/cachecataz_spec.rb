require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe MockModel do
  describe "disabled" do
    
    before(:all) do
      Cachecataz.enable = false
      Cachecataz.random = false
    end
    
    it "is disabled on initialization for cache_scope :user" do
      subject.cache_key(:user).should include("cachecataz disabled")
    end
    
    it "is disabled on initialization for cache_scope :user, [:id, :user_id]" do
      subject.cache_key(:user, [:id, :user_id]).should include("cachecataz disabled")
    end    
  end
  
  describe "basic namespacing" do
    subject { MockModel.new }
    
    before(:all) do
      Cachecataz.enable = true
      Cachecataz.provider = MockCache.new
      Cachecataz.random = false
    end

    it "returns a namespace key for an empty cache_scope" do
      subject.cache_key(:empty).should eq("0:empty")
    end
    
    it "returns a namespace key for cache_scope :user" do
      subject.cache_key(:user).should eq("0:user:#{subject.user_id}")
    end
    
    it "returns a multi namespace key for cache_scope :multi" do
      subject.cache_key(:multi).should eq("0:multi:#{subject.id}:#{subject.user_id}")
    end

    it "returns a namespace key with index for and empty cache_scope :empty, :id" do
      subject.cache_key(:empty, :id).should eq("0:empty/#{subject.id}")
    end

    it "returns a namespace key with index for cache_scope :user, :id" do
      subject.cache_key(:user, :id).should eq("0:user:#{subject.user_id}/#{subject.id}")
    end
    
    it "returns a multi namespace key for cache_scope :multi, :assoc_id" do
      subject.cache_key(:multi, :assoc_id).should eq("0:multi:#{subject.id}:#{subject.user_id}/#{subject.assoc_id}")
    end
    
    it "returns the same value for each key request on single variable non indexed cache_scope :user" do
      10.times do
        subject.cache_key(:user).should eq(subject.cache_key(:user))
      end
    end

    it "returns the same value for each key request on mutli variable non indexed cache_scope :multi" do
      10.times do
        subject.cache_key(:multi).should eq(subject.cache_key(:multi))
      end
    end

    it "returns the same value for each key request on single variable indexed cache_scope :user, :id" do
      10.times do
        subject.cache_key(:user, :id).should eq(subject.cache_key(:user, :id))
      end
    end

    it "returns the same value for each key request on multi variable indexed cache_scope :multi, :assoc_id" do
      10.times do
        subject.cache_key(:multi, :assoc_id).should eq(subject.cache_key(:multi, :assoc_id))
      end
    end
    
    it "expires a namespace key for a single variable cache_scope :user" do
      subject.expire_namespace(:user)
      subject.cache_key(:user).should eq("1:user:#{subject.user_id}")
    end

    it "expires a namespace with index key for a mutli variable cache_scope :multi" do
      subject.expire_namespace(:multi)
      subject.cache_key(:multi).should eq("1:multi:#{subject.id}:#{subject.user_id}")
    end
    
    it "expires a namespace key with index for cache_scope :user, :id" do
      subject.expire_namespace(:user)
      subject.cache_key(:user, :id).should eq("2:user:#{subject.user_id}/#{subject.id}")
    end
    
    it "expires a multi namespace key with index for cache_scope :multi, :assoc_id" do
      subject.expire_namespace(:multi)
      subject.cache_key(:multi, :assoc_id).should eq("2:multi:#{subject.id}:#{subject.user_id}/#{subject.assoc_id}")
    end
    
    describe "namespace delimiter change" do
      before(:all) do
        Cachecataz::Config[:provider].clear # not part of api, just an easy way to clear the mock cache
        Cachecataz.delimiter = ["|", "/"]
        Cachecataz.random = false
      end
      
      it "returns a namespace key with index for cache_scope :user, :id" do
        subject.cache_key(:user, :id).should eq("0|user|#{subject.user_id}/#{subject.id}")
      end
      
      it "returns a multi namespace key for cache_scope :multi, :assoc_id" do
        subject.cache_key(:multi, :assoc_id).should eq("0|multi|#{subject.id}|#{subject.user_id}/#{subject.assoc_id}")
      end        
    end
    
    describe "index delimiter change" do
      before(:all) do
        Cachecataz::Config[:provider].clear  # not part of api, just an easy way to clear the mock cache
        Cachecataz.delimiter = [":", "|"]
        Cachecataz.random = false
      end
      
      it "returns a namespace key with index for cache_scope :user, :id" do
        subject.cache_key(:user, :id).should eq("0:user:#{subject.user_id}|#{subject.id}")
      end
      
      it "returns a multi namespace key for cache_scope :multi, :assoc_id" do
        subject.cache_key(:multi, :assoc_id).should eq("0:multi:#{subject.id}:#{subject.user_id}|#{subject.assoc_id}")
      end        
    end
    
    describe "redefine api respond_to :call" do
      before(:all) do
        Cachecataz::Config[:provider].clear
        Cachecataz.delimiter = [":", "/"]
        Cachecataz.api = {:get => lambda{ |*args| Cachecataz::Config[:provider].all(:read, *args) }, 
                          :set => lambda{ |*args| Cachecataz::Config[:provider].all(:write, *args) }, 
                          :incr => lambda{ |*args| Cachecataz::Config[:provider].all(:increment, *args) }, 
                          :exist? => lambda{ |*args| Cachecataz::Config[:provider].all(:exist?, *args) }}
        Cachecataz.random = false
      end
  
      it "returns a namespace key for an empty cache_scope" do
        subject.cache_key(:empty).should eq("0:empty")
      end
      
      it "returns a namespace key for cache_scope :user" do
        subject.cache_key(:user).should eq("0:user:#{subject.user_id}")
      end
      
      it "returns a multi namespace key for cache_scope :multi" do
        subject.cache_key(:multi).should eq("0:multi:#{subject.id}:#{subject.user_id}")
      end

      it "returns a namespace key with index for and empty cache_scope :empty, :id" do
        subject.cache_key(:empty, :id).should eq("0:empty/#{subject.id}")
      end
    end    
  end
end
