class Photo
  class << self
    def mongo_client
      Mongoid::Clients.default
    end
  end

  attr_accessor :id, :location
  attr_writer :contents

  def initialize()
    
  end
end
