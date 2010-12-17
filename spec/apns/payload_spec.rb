require File.dirname(__FILE__) + '/../spec_helper'

describe APNS::Payload do
  
  def payload(message, token = "a-device-token")
    APNS::Payload.new(token, message)
  end
  it "should take a string as the message" do
    p = payload('Hello')
    p.should be_valid
  end
  
  it "should take a hash as the message" do
    p = payload({:alert => 'Hello iPhone', :badge => 3})
    p.should be_valid
  end

  it "should not validate a message longer than 256 bytes" do
    p = payload({:alert => 'A' * 250})
    p.size.should > 256
    p.should_not be_valid
  end
  
  it "should validate a message of 256 bytes or less" do
    p = payload({:alert => 'A' * 224})
    p.size.should == 256
    p.should be_valid
  end

  it "should strip whitespace from payload string" do
    p = payload("Hello iPhone  \n")
    p.should be_valid
    p.apn_message.should == { :aps => { :alert => 'Hello iPhone' } }
  end
  
  describe '#packaged_message' do
    
    it "should return JSON with payload informations" do
      p = payload({:alert => 'Hello iPhone', :badge => 2, :custom => "custom-string"})
      p.apn_message.should == { :aps => { :badge => 2, :alert => 'Hello iPhone' }, :custom => "custom-string" }
    end

    it "should return JSON with payload informations with whitespace stripped" do
      p = payload({:alert => "Hello iPhone  \n", :badge => 2, :custom => "custom-string  \n"})
      p.apn_message.should == { :aps => { :badge => 2, :alert => 'Hello iPhone' }, :custom => "custom-string" }
    end
    
    it "should not include keys that are empty in the JSON" do
      p = payload({:badge => 3})
      p.apn_message.should == { :aps => { :badge => 3 } }
    end
    
  end
  
  describe '#to_ssl' do
    it "should package the token and message" do
      p = APNS::Payload.new('<5b51030d d5bad758 fbad5004 bad35c31 e4e0f550 f77f20d4 f737bf8d 3d5524c6>', {:alert => 'Hello iPhone'})
      Base64.encode64(p.to_ssl).should == "AAAgW1EDDdW611j7rVAEutNcMeTg9VD3fyDU9ze/jT1VJMYAIHsiYXBzIjp7\nImFsZXJ0IjoiSGVsbG8gaVBob25lIn19\n"
    end
  end
  
end